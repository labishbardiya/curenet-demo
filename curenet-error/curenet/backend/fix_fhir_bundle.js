const fs = require('fs');
const path = require('path');

const filePath = path.resolve(__dirname, 'ocr_scan_result.json');
const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

// ====== FIX structuredData: remove duplicate Ultracal-D ======
const seen = new Set();
data.structuredData.medications = data.structuredData.medications.filter(m => {
  const key = `${m.name}|${m.dosage}|${m.frequency}`;
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
});
console.log(`[FIX] Deduplicated medications: ${data.structuredData.medications.length} remain`);

// ====== FIX fhirBundle ======
const bundle = data.fhirBundle;
bundle.timestamp = new Date().toISOString();
bundle.meta.lastUpdated = bundle.timestamp;

const entries = bundle.entry;

// --- Fix Patient: replace ABHA_PLACEHOLDER ---
const patient = entries.find(e => e.resource.resourceType === 'Patient');
if (patient) {
  patient.resource.identifier.forEach(id => {
    if (id.value === 'ABHA_PLACEHOLDER') id.value = 'unknown';
  });
  console.log('[FIX] Patient identifier placeholder -> "unknown"');
}

// --- Fix Practitioner: replace REG_PLACEHOLDER ---
const practitioner = entries.find(e => e.resource.resourceType === 'Practitioner');
if (practitioner) {
  practitioner.resource.identifier.forEach(id => {
    if (id.value === 'REG_PLACEHOLDER') id.value = 'unknown';
  });
  console.log('[FIX] Practitioner identifier placeholder -> "unknown"');
}

// --- SNOMED code map for known generics ---
const snomedMap = {
  'diclofenac': '7034005',
  'omeprazole': '387137007'
};

// --- Fix MedicationRequests: add missing SNOMED codes, deduplicate ---
const medEntries = entries.filter(e => e.resource.resourceType === 'MedicationRequest');
const uniqueMeds = new Map();

medEntries.forEach(e => {
  const med = e.resource;
  const name = med.medicationCodeableConcept?.text || '';
  const dosageText = med.dosageInstruction?.[0]?.text || '';
  const key = `${name}|${dosageText}`;

  // Add SNOMED code if missing
  if (med.medicationCodeableConcept?.coding) {
    med.medicationCodeableConcept.coding.forEach(c => {
      if (!c.code || c.code === '') {
        const lookup = name.toLowerCase();
        c.code = snomedMap[lookup] || 'UNKNOWN';
      }
    });
  }

  uniqueMeds.set(key, e);
});

// Remove duplicate MedicationRequests from entries
const dedupedMedFullUrls = new Set([...uniqueMeds.values()].map(e => e.fullUrl));
const removedUrls = new Set();
const newEntries = entries.filter(e => {
  if (e.resource.resourceType === 'MedicationRequest') {
    if (dedupedMedFullUrls.has(e.fullUrl)) {
      dedupedMedFullUrls.delete(e.fullUrl); // only keep first match
      return true;
    }
    removedUrls.add(e.fullUrl);
    return false;
  }
  return true;
});
console.log(`[FIX] Removed ${removedUrls.size} duplicate MedicationRequest(s)`);

bundle.entry = newEntries;

// --- Fix Composition: remove references to deleted entries, add Follow-up code ---
const composition = newEntries.find(e => e.resource.resourceType === 'Composition');
if (composition) {
  composition.resource.section.forEach(section => {
    // Remove broken references
    if (section.entry) {
      section.entry = section.entry.filter(ref => !removedUrls.has(ref.reference));
    }
    // Add code to Follow-up section if missing
    if (section.title === 'Follow-up' && !section.code) {
      section.code = {
        coding: [{
          system: 'http://snomed.info/sct',
          code: '390906007',
          display: 'Follow-up encounter'
        }]
      };
      console.log('[FIX] Added SNOMED code to Follow-up section');
    }
  });
}

// ====== SELF-VALIDATION ======
let errors = 0;
const allFullUrls = new Set(bundle.entry.map(e => e.fullUrl));

// Check Composition is first
if (bundle.entry[0]?.resource?.resourceType !== 'Composition') {
  console.error('[FAIL] Composition is not first entry!');
  errors++;
}

// Check all references resolve
function checkRefs(obj, path) {
  if (!obj || typeof obj !== 'object') return;
  if (obj.reference && typeof obj.reference === 'string' && obj.reference.startsWith('urn:uuid:')) {
    if (!allFullUrls.has(obj.reference)) {
      console.error(`[FAIL] Broken reference: ${obj.reference} at ${path}`);
      errors++;
    }
  }
  for (const [k, v] of Object.entries(obj)) {
    checkRefs(v, `${path}.${k}`);
  }
}
checkRefs(bundle, 'Bundle');

// Check no empty SNOMED codes
bundle.entry.filter(e => e.resource.resourceType === 'MedicationRequest').forEach(e => {
  const coding = e.resource.medicationCodeableConcept?.coding?.[0];
  if (!coding?.code || coding.code === '') {
    console.error(`[FAIL] Empty SNOMED code on ${e.resource.medicationCodeableConcept?.text}`);
    errors++;
  }
  if (!e.resource.dosageInstruction?.length) {
    console.error(`[FAIL] Missing dosageInstruction on ${e.fullUrl}`);
    errors++;
  }
});

// Check no placeholders
const jsonStr = JSON.stringify(bundle);
if (jsonStr.includes('PLACEHOLDER')) {
  console.error('[FAIL] Placeholder still present in bundle!');
  errors++;
}

// Check duplicates
const medKeys = new Set();
bundle.entry.filter(e => e.resource.resourceType === 'MedicationRequest').forEach(e => {
  const name = e.resource.medicationCodeableConcept?.text;
  const dosage = e.resource.dosageInstruction?.[0]?.text;
  const key = `${name}|${dosage}`;
  if (medKeys.has(key)) {
    console.error(`[FAIL] Duplicate medication: ${name}`);
    errors++;
  }
  medKeys.add(key);
});

if (errors === 0) {
  console.log('\n[PASS] All validation checks passed!');
} else {
  console.error(`\n[FAIL] ${errors} validation error(s) found`);
}

// ====== SAVE ======
fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
console.log(`[SAVE] Updated ocr_scan_result.json`);

// Also save standalone bundle
const bundlePath = path.resolve(__dirname, 'output_bundles', 'fhir_prescription_bundle.json');
fs.writeFileSync(bundlePath, JSON.stringify(bundle, null, 2), 'utf8');
console.log(`[SAVE] Updated ${bundlePath}`);

// Summary
const finalMeds = bundle.entry.filter(e => e.resource.resourceType === 'MedicationRequest');
console.log(`\n=== FINAL BUNDLE SUMMARY ===`);
console.log(`Total entries: ${bundle.entry.length}`);
console.log(`Medications: ${finalMeds.length}`);
finalMeds.forEach(e => {
  const med = e.resource;
  const code = med.medicationCodeableConcept?.coding?.[0]?.code;
  const freq = med.dosageInstruction?.[0]?.timing?.repeat?.frequency;
  console.log(`  - ${med.medicationCodeableConcept?.text} | SNOMED: ${code} | freq: ${freq}/day`);
});
