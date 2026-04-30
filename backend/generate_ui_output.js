const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'ocr_scan_result.json'), 'utf8'));
const bundle = data.fhirBundle;
const sd = data.structuredData;

// STEP 1: Classification
const docType = sd.medications && sd.medications.length > 0 ? 'prescription' : 'other';

// STEP 3: UI-optimized output
const ui_data = {
  document_type: docType,
  summary: {
    date: sd.date,
    doctor: sd.doctor_name,
    facility: sd.clinic,
    patient: sd.patient_name,
    chief_complaint: sd.chief_complaint
  },
  medications: sd.medications.map(m => ({
    name: m.name,
    dosage: m.dosage,
    frequency: m.frequency,
    duration: m.duration,
    route: m.route,
    form: m.form
  })),
  lab_results: [],
  follow_up: {
    date: sd.follow_up?.date || null,
    advice: sd.follow_up?.advice || []
  },
  investigations: sd.investigations || null
};

const output = {
  fhir_bundle: bundle,
  ui_data: ui_data
};

const outPath = path.resolve(__dirname, 'output_bundles', 'fhir_ui_output.json');
fs.writeFileSync(outPath, JSON.stringify(output, null, 2), 'utf8');
console.log(`[DONE] Combined output saved to: ${outPath}`);
console.log(`Document type: ${docType}`);
console.log(`Medications: ${ui_data.medications.length}`);
console.log(`\nUI Data Preview:`);
console.log(JSON.stringify(ui_data, null, 2));
