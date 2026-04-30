const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const Record = require('../models/recordModel');

/**
 * ═══════════════════════════════════════════════════════════════════
 *  Orchestrated Hybrid OCR Pipeline (v3)
 * ═══════════════════════════════════════════════════════════════════
 */
const runJob = async (jobRecord) => {
    let tempFiles = [];

    try {
        console.log(`[Worker] Starting REAL OCR pipeline for Job: ${jobRecord.jobId}`);
        const _filePath = jobRecord.filePath;
        tempFiles.push(_filePath);
        
        // Execute the real OCR pipeline script
        const backendRoot = path.join(__dirname, '../../');
        console.log(`[Worker] Running Tesseract & Gemini pipeline...`);
        execSync(`node process_prescription.js "${_filePath}"`, { cwd: backendRoot, stdio: 'inherit' });

        // Read the generated output
        const scanResultPath = path.join(backendRoot, 'ocr_scan_result.json');
        if (!fs.existsSync(scanResultPath)) {
            throw new Error("OCR pipeline failed to produce output.");
        }

        const combinedResult = JSON.parse(fs.readFileSync(scanResultPath, 'utf8'));
        const fhir_bundle = combinedResult.fhirBundle;
        const ui_data = combinedResult.ui_data || combinedResult.uiData || combinedResult.uiOutput;
        const structuredData = combinedResult.structuredData;
        const raw_text = combinedResult.ocrOutput ? combinedResult.ocrOutput.raw_text : "No raw text available";

        const ocrConfidence = combinedResult.metadata ? combinedResult.metadata.ocrConfidence : 0.95;
        const overallConfidence = ocrConfidence;

        // Recalculate final confidence after potential fallback
        const finalMedConf = (structuredData.medications || []).map(m => m.confidence || 0.85);
        const finalLabConf = (structuredData.lab_results || []).map(() => 0.85);
        const finalAllConf = [...finalMedConf, ...finalLabConf];
        const finalConfidence = finalAllConf.length > 0
            ? (ocrConfidence + finalAllConf.reduce((a, b) => a + b, 0) / finalAllConf.length) / 2
            : ocrConfidence;

        // 6. Save to job record
        jobRecord.raw_text = raw_text;
        jobRecord.confidence_score = finalConfidence;
        jobRecord.status = 'completed';
        jobRecord.fhirBundle = fhir_bundle;
        jobRecord.uiData = ui_data;

        // ABDM context for quick UI access
        jobRecord.abdmContext = {
            patientName: structuredData.patient_name || structuredData.patientName,
            doctorName: structuredData.doctor_name || structuredData.doctorName,
            documentType: ui_data && ui_data.document_type ? ui_data.document_type : 'Prescription',
            medicationCount: ui_data && ui_data.medications ? ui_data.medications.length : (structuredData.medications ? structuredData.medications.length : 0),
            labResultCount: ui_data && ui_data.lab_results ? ui_data.lab_results.length : 0,
            isReliable: finalConfidence >= 0.75
        };

        await jobRecord.save();
        
        // 7. Save FHIR Bundle to local file
        const outputDir = path.join(__dirname, '../../output_bundles');
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }
        
        // Save FHIR bundle
        const bundlePath = path.join(outputDir, `fhir_bundle_${jobRecord.jobId}.json`);
        fs.writeFileSync(bundlePath, JSON.stringify(fhir_bundle, null, 2));
        
        // Save combined output { fhir_bundle, ui_data }
        const combinedPath = path.join(outputDir, `fhir_ui_output_${jobRecord.jobId}.json`);
        fs.writeFileSync(combinedPath, JSON.stringify({ fhir_bundle, ui_data }, null, 2));

        console.log(`[Worker] Job ${jobRecord.jobId} completed. Type: ${ui_data.document_type}, Accuracy: ${(overallConfidence * 100).toFixed(1)}%`);
        console.log(`[Worker] FHIR Bundle: ${bundlePath}`);

    } catch (err) {
        console.error(`[Worker] Pipeline failed for Job: ${jobRecord.jobId}. Error: ${err.message}`);
        jobRecord.status = 'failed';
        jobRecord.error = err.message;
        await jobRecord.save();
    } finally {
        // Cleanup local generated temp files
        tempFiles.forEach(file => {
            if (file !== jobRecord.filePath && fs.existsSync(file)) {
                try { fs.unlinkSync(file); } catch (e) { /* ignore */ }
            }
        });
    }
};

/**
 * Worker polling wrapper. 
 */
const pollQueue = async () => {
    try {
        console.log(`[Worker Poller] Checking for pending jobs...`);
        const jobRecord = await Record.findOneAndUpdate(
            { status: 'pending' },
            { status: 'processing' },
            { new: true }
        );

        if (jobRecord) {
            console.log(`[Worker Poller] Picked up job ${jobRecord.jobId}`);
            await runJob(jobRecord);
        }
    } catch (err) {
        console.error('[Worker Poller] Error polling jobs:', err.message);
    } finally {
        setTimeout(pollQueue, 3000);
    }
};

pollQueue();

module.exports = { runJob };
