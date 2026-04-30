/**
 * ═══════════════════════════════════════════════════════════════════════
 *  CureNet Prescription Processor (v2.0)
 * ═══════════════════════════════════════════════════════════════════════
 *
 *  Full automated pipeline:
 *    Step 1: Preprocess image (sharp — denoise, contrast, sharpen)
 *    Step 2: Tesseract.js OCR (English)
 *    Step 3: Multi-strategy extraction (regex + fuzzy + fragment matching)
 *    Step 4: Gemini Vision API fallback (if OCR confidence < 50%)
 *    Step 5: Build ABDM-compliant FHIR R4 Document Bundle
 *    Step 6: Save all outputs
 *
 *  Usage:
 *    node process_prescription.js [path-to-image]
 *    node process_prescription.js               (defaults to ../image.png)
 *
 * ═══════════════════════════════════════════════════════════════════════
 */
require('dotenv').config();
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const Tesseract = require('tesseract.js');
const Levenshtein = require('fast-levenshtein');
const axios = require('axios');
const { processDocument } = require('./src/services/documentProcessor');
const { validateFhirBundle } = require('./src/utils/fhirBuilder');

// ─── Load Medical Dictionary ─────────────────────────────────────────────────
const dictionaryPath = path.join(__dirname, 'src/utils/medical_dictionary.json');
let medDictionary = { medications: [], common_ocr_corrections: {}, frequency_patterns: {} };
try {
    medDictionary = JSON.parse(fs.readFileSync(dictionaryPath, 'utf8'));
} catch (e) {
    console.warn('[Init] Medical dictionary not found, using empty dictionary.');
}

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const CONFIDENCE_THRESHOLD = 50; // Below this we trigger Vision LLM fallback

// ═══════════════════════════════════════════════════════════════════════
//  STEP 1: IMAGE PREPROCESSING
// ═══════════════════════════════════════════════════════════════════════

/**
 * Enhances a prescription image for better OCR accuracy using sharp.
 * - Converts to greyscale
 * - Normalizes contrast/brightness
 * - Sharpens text edges
 * - Optionally increases resolution
 */
async function preprocessImage(inputPath) {
    const outputPath = path.join(path.dirname(inputPath), '_preprocessed_temp.png');

    try {
        const metadata = await sharp(inputPath).metadata();
        let pipeline = sharp(inputPath);

        // Upscale small images (< 1500px wide) for better OCR
        if (metadata.width < 1500) {
            const scale = Math.ceil(1500 / metadata.width);
            pipeline = pipeline.resize(metadata.width * scale, null, {
                kernel: sharp.kernel.lanczos3
            });
        }

        await pipeline
            .greyscale()                             // Convert to greyscale
            .normalize()                             // Auto-contrast stretch
            .sharpen({ sigma: 1.5 })                 // Sharpen text edges
            .linear(1.2, -(128 * 1.2 - 128))        // Increase contrast
            .png({ quality: 100 })
            .toFile(outputPath);

        return outputPath;
    } catch (err) {
        console.warn(`[Preprocess] Sharp failed: ${err.message}. Using original image.`);
        return inputPath;
    }
}


// ═══════════════════════════════════════════════════════════════════════
//  STEP 2: TESSERACT OCR
// ═══════════════════════════════════════════════════════════════════════

/**
 * Runs Tesseract.js OCR on the preprocessed image.
 * Returns raw text, confidence, per-line and per-word data.
 */
async function runTesseractOcr(imagePath) {
    const { data } = await Tesseract.recognize(imagePath, 'eng', {
        logger: (m) => {
            if (m.status === 'recognizing text') {
                process.stdout.write(`\r  OCR Progress: ${(m.progress * 100).toFixed(0)}%`);
            }
        }
    });

    return {
        raw_text: data.text,
        confidence: data.confidence,
        lines: data.lines.map(l => ({
            text: l.text.trim(),
            confidence: l.confidence,
            bbox: l.bbox
        })),
        words: data.words.map(w => ({
            text: w.text,
            confidence: w.confidence,
            bbox: w.bbox
        }))
    };
}


// ═══════════════════════════════════════════════════════════════════════
//  STEP 3: MULTI-STRATEGY TEXT PARSER
// ═══════════════════════════════════════════════════════════════════════

/**
 * Normalizes a drug name using fuzzy matching against the medical dictionary.
 */
function normalizeDrugName(rawName) {
    if (!rawName || rawName === 'unclear') return rawName;

    const cleanName = rawName.replace(/[\s\-]+/g, '').toLowerCase();

    // 1. Check OCR correction map first (exact matches for known OCR errors)
    for (const [wrong, correct] of Object.entries(medDictionary.common_ocr_corrections || {})) {
        if (cleanName.includes(wrong.replace(/[\s\-]+/g, '').toLowerCase())) {
            return correct;
        }
    }

    // 2. Fuzzy match against medication list
    let bestMatch = rawName;
    let minDistance = Infinity;
    const threshold = Math.max(2, Math.floor(rawName.length * 0.35));

    for (const drug of medDictionary.medications || []) {
        const dist = Levenshtein.get(rawName.toLowerCase(), drug.toLowerCase());
        if (dist < minDistance) {
            minDistance = dist;
            bestMatch = drug;
        }
    }

    return (minDistance <= threshold) ? bestMatch : rawName;
}

/**
 * Detects the dosage form prefix (Tab./Cap./Syp. etc.) from a line.
 */
function detectForm(line) {
    const formMap = {
        'tab': 'Tablet', 'tbs': 'Tablet', 'tots': 'Tablet',
        'cap': 'Capsule',
        'syp': 'Syrup', 'syr': 'Syrup',
        'inj': 'Injection',
        'oint': 'Ointment',
        'drop': 'Drops', 'drp': 'Drops',
        'susp': 'Suspension',
        'cream': 'Cream',
        'gel': 'Gel',
        'lotion': 'Lotion'
    };

    for (const [prefix, form] of Object.entries(formMap)) {
        const regex = new RegExp(`\\b${prefix}\\.?\\s`, 'i');
        if (regex.test(line)) return form;
    }
    return null;
}

/**
 * Extracts structured data from raw OCR text using multi-pattern regex matching.
 */
function parseOcrText(rawText) {
    const lines = rawText.split('\n').map(l => l.trim()).filter(l => l.length > 2);

    let patientName = 'unclear';
    let doctorName = 'unclear';
    let prescriptionDate = new Date().toISOString().split('T')[0];
    let age = null;
    const medications = [];

    // ─── Metadata extraction ─────────────────────────────────────────
    for (const line of lines) {
        // Patient name
        if (patientName === 'unclear') {
            const namePatterns = [
                /(?:name|patient|naam|নাম)\s*[:\-=]?\s*(.{3,40})/i,
                /(?:Mr\.|Mrs\.|Ms\.|Shri|Smt)\s+(.{3,40})/i
            ];
            for (const pat of namePatterns) {
                const m = line.match(pat);
                if (m) { patientName = m[1].replace(/\s+/g, ' ').trim(); break; }
            }
        }

        // Doctor name
        if (doctorName === 'unclear') {
            const m = line.match(/(?:Dr\.?|ডাঃ|डॉ\.?)\s*(.{3,50}?)(?:\s*$|,|\()/i);
            if (m) doctorName = m[1].trim();
        }

        // Date (DD/MM/YY, DD-MM-YYYY, DD.MM.YY)
        const dateMatch = line.match(/(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/);
        if (dateMatch) {
            const [_, d, m, y] = dateMatch;
            const year = y.length === 2 ? (parseInt(y) > 50 ? `19${y}` : `20${y}`) : y;
            prescriptionDate = `${year}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
        }

        // Age
        if (!age) {
            const ageMatch = line.match(/(?:age|বয়স)\s*[:\-]?\s*(\d{1,3})\s*(?:y|yr|yrs|years)?/i);
            if (ageMatch) age = `${ageMatch[1]}Y`;
        }
    }

    // ─── Medication extraction ───────────────────────────────────────
    const medPrefixRegex = /\b(?:Tab|Cap|Syp|Syr|Inj|Oint|Drop|Drp|Susp|Tbs|Tots|Cream|Gel)\.?\s+/i;
    const dosageRegex = /(\d+\s*(?:mg|ml|mcg|gm|g|IU|units?))/i;
    const freqRegex = /((?:\d\s*[\+\-x]\s*\d\s*[\+\-x]\s*\d)|(?:once|twice|thrice)\s*(?:daily|a\s*day)|OD|BD|TID|QID|HS|SOS)/i;
    const durationRegex = /(\d+\s*(?:days?|wk|weeks?|months?|mon))/i;

    for (const line of lines) {
        if (!medPrefixRegex.test(line)) continue;

        const form = detectForm(line);
        const dosageMatch = line.match(dosageRegex);
        const freqMatch = line.match(freqRegex);
        const durMatch = line.match(durationRegex);

        // Extract medicine name: text after the prefix, before the first number/dosage
        let afterPrefix = line.replace(medPrefixRegex, '').replace(/^\d+[.)]\s*/, '');
        const matchIndices = [dosageMatch, freqMatch, durMatch]
            .filter(m => m)
            .map(m => afterPrefix.indexOf(m[0]))
            .filter(i => i > 0);

        let medName;
        if (matchIndices.length > 0) {
            medName = afterPrefix.substring(0, Math.min(...matchIndices));
        } else {
            medName = afterPrefix;
        }

        medName = medName.replace(/[\-—–,\s]+$/, '').trim();
        if (medName.length < 2) continue;

        // Normalize against dictionary
        const normalizedName = normalizeDrugName(medName);

        // Calculate confidence
        let confidence = 0.4;
        if (dosageMatch) confidence += 0.15;
        if (freqMatch) confidence += 0.2;
        if (durMatch) confidence += 0.1;
        if (normalizedName !== medName) confidence += 0.1; // Dictionary match bonus

        medications.push({
            name: normalizedName,
            dosage: dosageMatch ? dosageMatch[1] : 'as prescribed',
            frequency: freqMatch ? freqMatch[1] : 'unclear',
            duration: durMatch ? durMatch[1] : 'as directed',
            route: 'oral',
            form: form || 'Tablet',
            confidence: Math.min(confidence, 0.95),
            extraction_method: 'ocr_regex_parse',
            raw_text: line
        });
    }

    return {
        patient_name: patientName,
        doctor_name: doctorName,
        date: prescriptionDate,
        age,
        medications
    };
}


// ═══════════════════════════════════════════════════════════════════════
//  STEP 4: GEMINI VISION API FALLBACK
// ═══════════════════════════════════════════════════════════════════════

/**
 * Sends the original prescription image to Gemini Vision API for
 * structured extraction when local OCR confidence is too low.
 */
async function extractWithGeminiVision(imagePath) {
    if (!GEMINI_API_KEY || GEMINI_API_KEY === 'YOUR_GEMINI_API_KEY_HERE') {
        console.warn('  ⚠️  Gemini API key not configured — skipping Vision LLM fallback.');
        return null;
    }

    try {
        const imageBuffer = fs.readFileSync(imagePath);
        const base64Image = imageBuffer.toString('base64');
        const mimeType = imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg';

        const prompt = `You are a medical data extraction expert. Analyze this handwritten prescription image carefully.

Extract ALL information and return ONLY valid JSON in this exact format:
{
  "patient_name": "full name or 'unclear'",
  "doctor_name": "full name with title or 'unclear'",
  "clinic": "clinic/hospital name or 'unclear'",
  "date": "YYYY-MM-DD format",
  "age": "e.g. 35Y or 'unclear'",
  "chief_complaint": "diagnosis/complaint text or 'unclear'",
  "investigations": "any tests advised or 'unclear'",
  "medications": [
    {
      "name": "exact medicine name",
      "dosage": "e.g. 50mg",
      "frequency": "e.g. 2+0+2 or BD",
      "duration": "e.g. 2 weeks",
      "form": "Tablet/Capsule/Syrup/Injection",
      "route": "oral/topical/injection"
    }
  ],
  "follow_up": {
    "date": "YYYY-MM-DD or null",
    "advice": ["advice item 1", "advice item 2"]
  }
}

Rules:
- Read every medication line carefully, including handwritten text
- Indian prescription frequency format: morning+afternoon+night (e.g., 1+0+1, 2+0+2)
- Common abbreviations: Tab=Tablet, Cap=Capsule, Syp=Syrup, Inj=Injection
- If multiple visits are on the same page, include ALL medications from ALL visits
- Do NOT hallucinate — if something is truly unreadable, mark as 'unclear'
- Return ONLY the JSON, no markdown formatting`;

        console.log('  📡 Calling Gemini Vision API...');
        const response = await axios.post(
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`,
            {
                contents: [{
                    parts: [
                        { text: prompt },
                        { inline_data: { mime_type: mimeType, data: base64Image } }
                    ]
                }]
            },
            { timeout: 30000 }
        );

        const textResult = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!textResult) return null;

        // Clean markdown backticks if present
        const cleanJson = textResult.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
        const parsed = JSON.parse(cleanJson);

        // Add confidence and extraction method to medications
        if (parsed.medications) {
            parsed.medications = parsed.medications.map(med => ({
                ...med,
                confidence: 0.92,
                extraction_method: 'gemini_vision'
            }));
        }

        console.log(`  ✅ Gemini returned ${parsed.medications?.length || 0} medication(s)`);
        return parsed;

    } catch (err) {
        console.error(`  ❌ Gemini API failed: ${err.message}`);
        return null;
    }
}


// ═══════════════════════════════════════════════════════════════════════
//  MAIN PIPELINE
// ═══════════════════════════════════════════════════════════════════════

async function processPrescription(imagePath) {
    console.log(`\n${'═'.repeat(65)}`);
    console.log(`  CureNet Prescription Processor v2.0`);
    console.log(`  Source: ${path.basename(imagePath)}`);
    console.log(`${'═'.repeat(65)}\n`);

    const startTime = Date.now();
    let preprocessedPath = null;

    try {
        const fullPath = path.resolve(imagePath);
        if (!fs.existsSync(fullPath)) {
            console.error(`❌ File not found: ${fullPath}`);
            process.exit(1);
        }

        // ─── Step 1: Preprocess ──────────────────────────────────────
        console.log('[Step 1/5] 🖼️  Preprocessing image with Sharp...');
        const prepStart = Date.now();
        preprocessedPath = await preprocessImage(fullPath);
        const usedPreprocessed = preprocessedPath !== fullPath;
        console.log(`  ✅ Done in ${((Date.now() - prepStart) / 1000).toFixed(2)}s ${usedPreprocessed ? '(enhanced)' : '(original)'}`);

        // ─── Step 2: Tesseract OCR ───────────────────────────────────
        console.log('\n[Step 2/5] 🔍 Running Tesseract.js OCR (English)...');
        const ocrStart = Date.now();
        const ocrResult = await runTesseractOcr(preprocessedPath);
        console.log(`\n  ✅ OCR done in ${((Date.now() - ocrStart) / 1000).toFixed(2)}s`);
        console.log(`  📄 Confidence: ${ocrResult.confidence.toFixed(1)}%`);
        console.log(`  📝 Lines: ${ocrResult.lines.length} | Words: ${ocrResult.words.length}`);

        // Show top OCR lines for debugging
        const goodLines = ocrResult.lines.filter(l => l.confidence > 25);
        if (goodLines.length > 0) {
            console.log('  📋 Best OCR lines:');
            goodLines.slice(0, 8).forEach(l => {
                console.log(`     [${l.confidence.toFixed(0)}%] ${l.text}`);
            });
        }

        // ─── Step 3: Local Parser ────────────────────────────────────
        console.log('\n[Step 3/5] 🧩 Parsing OCR text (regex + fuzzy matching)...');
        let structuredData = parseOcrText(ocrResult.raw_text);
        console.log(`  Regex found ${structuredData.medications.length} medication(s)`);
        if (structuredData.medications.length > 0) {
            structuredData.medications.forEach((med, i) => {
                console.log(`     ${i + 1}. ${med.name} | ${med.dosage} | ${med.frequency}`);
            });
        }

        // ─── Step 4: Gemini Vision Fallback ──────────────────────────
        const needsFallback = ocrResult.confidence < CONFIDENCE_THRESHOLD
            || structuredData.medications.length < 2;

        if (needsFallback) {
            console.log(`\n[Step 4/5] 🤖 OCR confidence ${ocrResult.confidence.toFixed(0)}% < ${CONFIDENCE_THRESHOLD}% — triggering Gemini Vision fallback...`);

            const geminiResult = await extractWithGeminiVision(fullPath);

            if (geminiResult && geminiResult.medications && geminiResult.medications.length > 0) {
                // Gemini succeeded — use its output but preserve any good OCR data
                structuredData = {
                    ...geminiResult,
                    // Keep OCR data if Gemini missed certain fields
                    patient_name: geminiResult.patient_name !== 'unclear'
                        ? geminiResult.patient_name
                        : structuredData.patient_name,
                    doctor_name: geminiResult.doctor_name !== 'unclear'
                        ? geminiResult.doctor_name
                        : structuredData.doctor_name,
                    date: geminiResult.date || structuredData.date,
                };

                // Normalize all drug names through dictionary
                structuredData.medications = structuredData.medications.map(med => ({
                    ...med,
                    name: normalizeDrugName(med.name),
                    route: med.route || 'oral',
                    form: med.form || 'Tablet'
                }));

                console.log('  ✅ Using Gemini Vision extraction');
            } else {
                console.log('  ⚠️  Gemini fallback unavailable — using best local parse');
            }
        } else {
            console.log('\n[Step 4/5] ⏭️  OCR confidence adequate — skipping Gemini fallback');
        }

        // ─── Print final extraction ──────────────────────────────────
        console.log(`\n  ${'─'.repeat(55)}`);
        console.log(`  📋 FINAL EXTRACTION RESULT`);
        console.log(`  ${'─'.repeat(55)}`);
        console.log(`  👤 Patient:    ${structuredData.patient_name}`);
        console.log(`  🩺 Doctor:     ${structuredData.doctor_name}`);
        console.log(`  📅 Date:       ${structuredData.date}`);
        if (structuredData.age) console.log(`  📅 Age:        ${structuredData.age}`);
        if (structuredData.clinic) console.log(`  🏥 Clinic:     ${structuredData.clinic}`);
        if (structuredData.chief_complaint) console.log(`  🩹 Complaint:  ${structuredData.chief_complaint}`);
        if (structuredData.investigations) console.log(`  🔬 Invest:     ${structuredData.investigations}`);
        console.log(`  💊 Medications: ${structuredData.medications.length}`);
        structuredData.medications.forEach((med, i) => {
            const conf = med.confidence ? ` [${(med.confidence * 100).toFixed(0)}%]` : '';
            console.log(`     ${i + 1}. ${med.form || ''} ${med.name} ${med.dosage || ''} | ${med.frequency || ''} | ${med.duration || ''}${conf}`);
        });
        if (structuredData.follow_up) {
            console.log(`  📆 Follow-up:  ${structuredData.follow_up.date || 'TBD'}`);
            if (structuredData.follow_up.advice) {
                structuredData.follow_up.advice.forEach(a => console.log(`     • ${a}`));
            }
        }

        // ─── Step 5: Unified Document Processor ─────────────────────
        console.log(`\n[Step 5/5] 🏥 Running Unified Document Processor (Classify → FHIR → UI → Validate)...`);
        const { fhir_bundle, ui_data } = processDocument(structuredData, ocrResult.raw_text);
        const fhirBundle = fhir_bundle;
        console.log(`  ✅ Bundle generated: ${fhirBundle.entry.length} FHIR resources`);
        console.log(`  📦 Bundle ID: ${fhirBundle.id}`);
        console.log(`  📦 Bundle Type: ${fhirBundle.type}`);
        console.log(`  📋 Document Type: ${ui_data.document_type}`);

        // Validate
        const validation = validateFhirBundle(fhirBundle);
        if (validation.valid) {
            console.log(`  ✅ FHIR Validation: PASSED (0 errors)`);
        } else {
            console.warn(`  ⚠️  FHIR Validation: ${validation.errors.length} issue(s)`);
            validation.errors.forEach(e => console.warn(`     - ${e}`));
        }

        // ─── Save All Outputs ────────────────────────────────────────
        const outputDir = path.join(__dirname, 'output_bundles');
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }

        // 1. Raw OCR
        const ocrPath = path.join(outputDir, 'ocr_raw_output.json');
        fs.writeFileSync(ocrPath, JSON.stringify(ocrResult, null, 2));

        // 2. Structured data
        const structPath = path.join(outputDir, 'structured_data.json');
        fs.writeFileSync(structPath, JSON.stringify(structuredData, null, 2));

        // 3. FHIR Bundle (main deliverable)
        const fhirPath = path.join(outputDir, 'fhir_prescription_bundle.json');
        fs.writeFileSync(fhirPath, JSON.stringify(fhirBundle, null, 2));

        // 4. Combined output { fhir_bundle, ui_data }
        const uiOutputPath = path.join(outputDir, 'fhir_ui_output.json');
        fs.writeFileSync(uiOutputPath, JSON.stringify({ fhir_bundle, ui_data }, null, 2));

        // 5. Full pipeline result
        const combined = {
            metadata: {
                processedAt: new Date().toISOString(),
                totalProcessingTimeSeconds: (Date.now() - startTime) / 1000,
                sourceFile: path.basename(imagePath),
                ocrEngine: 'Tesseract.js v5 (English)',
                ocrConfidence: ocrResult.confidence,
                extractionMethod: structuredData.medications[0]?.extraction_method || 'unknown',
                pipelineVersion: '3.0.0',
                documentType: ui_data.document_type,
                medicationsFound: ui_data.medications.length,
                labResultsFound: ui_data.lab_results.length
            },
            ocrOutput: ocrResult,
            structuredData,
            fhirBundle,
            ui_data
        };
        const combinedPath = path.join(__dirname, 'ocr_scan_result.json');
        fs.writeFileSync(combinedPath, JSON.stringify(combined, null, 2));

        // ─── Print Summary ───────────────────────────────────────────
        console.log(`\n${'═'.repeat(65)}`);
        console.log(`  ✅ PIPELINE COMPLETE — ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
        console.log(`  ${'─'.repeat(55)}`);
        console.log(`  📁 OCR Raw:        ${ocrPath}`);
        console.log(`  📁 Structured:     ${structPath}`);
        console.log(`  📁 FHIR Bundle:    ${fhirPath}`);
        console.log(`  📁 UI Output:      ${uiOutputPath}`);
        console.log(`  📁 Combined:       ${combinedPath}`);
        console.log(`${'═'.repeat(65)}\n`);

        // Print FHIR resource summary
        console.log('📋 FHIR Resources:');
        fhirBundle.entry.forEach((entry, i) => {
            const r = entry.resource;
            switch (r.resourceType) {
                case 'Composition':
                    console.log(`  [${i}] Composition: "${r.title}" — ${r.section?.length || 0} section(s)`);
                    break;
                case 'Patient':
                    console.log(`  [${i}] Patient: ${r.name[0].text}`);
                    break;
                case 'Practitioner':
                    console.log(`  [${i}] Practitioner: ${r.name[0].text}`);
                    break;
                case 'Encounter':
                    console.log(`  [${i}] Encounter: ${r.class?.display || r.status}`);
                    break;
                case 'MedicationRequest':
                    console.log(`  [${i}] MedicationRequest: ${r.medicationCodeableConcept.text} → ${r.dosageInstruction[0].text}`);
                    break;
                default:
                    console.log(`  [${i}] ${r.resourceType}`);
            }
        });

    } catch (error) {
        console.error(`\n❌ CRITICAL ERROR: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    } finally {
        // Cleanup preprocessed temp file
        if (preprocessedPath && preprocessedPath.includes('_preprocessed_temp')) {
            try { fs.unlinkSync(preprocessedPath); } catch (_) {}
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════
const targetImage = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.join(__dirname, '../image.png');

processPrescription(targetImage);
