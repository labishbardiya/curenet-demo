require('dotenv').config();
const path = require('path');
const fs = require('fs');
const { runHybridOcr } = require('./src/services/ocr/pythonBridge');
const { parsePrescriptionText } = require('./src/services/ocr/parserService');
const { buildABDMDocumentBundle } = require('./src/utils/fhirBuilder');

async function processImage(imagePath) {
    console.log(`\n--- OCR PROCESSING START: ${path.basename(imagePath)} ---`);
    const startTime = Date.now();
    
    try {
        const fullPath = path.resolve(imagePath);
        if (!fs.existsSync(fullPath)) {
            console.error(`Error: File not found at ${fullPath}`);
            return;
        }

        // 1. Try Vision LLM (Gemini) for High-Accuracy Extraction
        console.log('[Step 1/3] Attempting High-Accuracy Vision LLM Extraction...');
        let structuredData = null;
        let ocrResult = { final_raw_text: '', printed_blocks: [], handwritten_summary: '' };
        
        try {
            const { extractWithVisionLlm } = require('./src/services/ocr/visionLlmService');
            structuredData = await extractWithVisionLlm(fullPath);
            if (structuredData) {
                console.log('Vision LLM Extraction Successful.');
            }
        } catch (err) {
            console.log('Vision LLM failed, falling back to local OCR...');
        }

        // 2. Fallback to Local Hybrid OCR if Vision LLM fails
        if (!structuredData) {
            console.log('[Step 2/3] Running Local Hybrid OCR Extraction Fallback...');
            const ocrStartTime = Date.now();
            ocrResult = await runHybridOcr(fullPath);
            console.log(`OCR Stage Completed in ${((Date.now() - ocrStartTime) / 1000).toFixed(2)}s`);

            console.log('[Step 2/3] Parsing Text via LLM/Regex Hybrid...');
            const parseStartTime = Date.now();
            structuredData = await parsePrescriptionText(ocrResult.final_raw_text);
            console.log(`Parsing Stage Completed in ${((Date.now() - parseStartTime) / 1000).toFixed(2)}s`);
        } else {
            console.log('[Step 2/3] Skipping Local OCR as Vision LLM provided structured data directly.');
        }

        // 3. Build FHIR R4 Bundle
        console.log('[Step 3/3] Generating ABDM-Compliant FHIR R4 Bundle...');
        const fhirBundle = buildABDMDocumentBundle(structuredData);

        // 4. Save results to file
        const output = {
            metadata: {
                processedAt: new Date().toISOString(),
                totalProcessingTimeSeconds: (Date.now() - startTime) / 1000,
                sourceFile: imagePath,
                extractionMethod: structuredData.source || 'local_hybrid_ocr'
            },
            ocrOutput: ocrResult,
            structuredData: structuredData,
            fhirBundle: fhirBundle
        };

        const outputPath = path.join(__dirname, 'ocr_scan_result.json');
        fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
        
        console.log('\n--- PROCESSING COMPLETE ---');
        console.log(`Total Time: ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
        console.log(`Result saved to: ${outputPath}`);
        console.log('Summary of medications found:', structuredData.medications?.length || 0);
        if (structuredData.medications) {
            structuredData.medications.forEach((med, i) => {
                console.log(`  ${i+1}. ${med.name} | ${med.dosage} | ${med.frequency}`);
            });
        }

    } catch (error) {
        console.error('\n[CRITICAL ERROR] Processing failed:', error);
    }
}

// Target the image.png in the root directory
const targetImage = path.join(__dirname, '../image.png');
processImage(targetImage);
