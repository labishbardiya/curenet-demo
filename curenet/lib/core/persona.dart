/// ─── CureNet Demo Persona ──────────────────────────────────────────────────
/// Single source of truth for Priya Sharma's clinical profile.
/// Used by: HomeScreen, ProfileScreen, RecordsScreen, EmergencySnapshotScreen,
///          AiService, ChatScreen.
///
/// In production this class would be populated from ABDM profile API + local vault.

class Persona {
  // ─── IDENTITY ──────────────────────────────────────────────────────────────
  static const String name = 'Priya Sharma';
  static const String abhaNumber = '91-2345-6789-0123';
  static const String abhaAddress = 'priya.sharma@abdm';
  static const String dob = '14 Mar 1985';
  static const int age = 39;
  static const String gender = 'Female';
  static const String bloodGroup = 'B+';
  static const String mobile = '+91 98765 43210';
  static const String email = 'priya.sharma@gmail.com';
  static const String address = '42, MG Road, Jaipur, Rajasthan 302001';

  // ─── EMERGENCY INFO ────────────────────────────────────────────────────────
  static const String emergencyContact = '+91 98765 43210 (Ravi Sharma - Husband)';
  static const String emergencyPhone = '+91 98765 43210';
  static const String emergencyRelation = 'Ravi Sharma (Husband)';
  static const String insuranceId = 'PMJAY-RJ-20230045';

  // ─── MEDICAL CONDITIONS ────────────────────────────────────────────────────
  static const List<String> conditions = [
    'Type 2 Diabetes Mellitus (Since 2021)',
    'Essential Hypertension (Since 2022)',
  ];
  static const String conditionsShort = 'Type 2 Diabetes, Hypertension';

  // ─── ALLERGIES ─────────────────────────────────────────────────────────────
  static const List<String> allergies = ['Penicillin', 'Peanuts'];
  static const String allergiesShort = 'Penicillin, Peanuts';

  // ─── ACTIVE MEDICATIONS ────────────────────────────────────────────────────
  static const List<Map<String, String>> medications = [
    {'name': 'Amlodipine', 'dosage': '5mg', 'frequency': 'Once daily (morning)', 'for': 'Hypertension'},
    {'name': 'Metformin', 'dosage': '500mg', 'frequency': 'Twice daily (after meals)', 'for': 'Diabetes'},
    {'name': 'Atorvastatin', 'dosage': '10mg', 'frequency': 'Once daily (night)', 'for': 'Cholesterol'},
  ];

  // ─── LATEST VITALS ─────────────────────────────────────────────────────────
  static const Map<String, String> vitals = {
    'HbA1c': '6.2% (Pre-diabetic)',
    'Fasting Glucose': '110 mg/dL',
    'Blood Pressure': '138/88 mmHg',
    'TSH': '3.8 uIU/mL (Normal)',
    'Total Cholesterol': '185 mg/dL',
    'LDL': '110 mg/dL',
    'HDL': '52 mg/dL',
    'BMI': '26.4 (Overweight)',
    'Weight': '68 kg',
    'Height': '160 cm',
  };

  // ─── PHYSICIANS ────────────────────────────────────────────────────────────
  static const Map<String, String> primaryPhysician = {
    'name': 'Dr. Suresh Kumar',
    'specialty': 'General Medicine & Diabetes',
    'hospital': 'Apollo Spectra, Jaipur',
    'phone': '+91 94140 12345',
  };

  static const List<Map<String, String>> doctors = [
    {'name': 'Dr. Suresh Kumar', 'specialty': 'General Medicine', 'hospital': 'Apollo Spectra, Jaipur'},
    {'name': 'Dr. Meena Kapoor', 'specialty': 'Pathology / Lab Diagnostics', 'hospital': 'SRL Diagnostics, Jaipur'},
    {'name': 'Dr. Anjali Mehta', 'specialty': 'Ophthalmology', 'hospital': 'Rajasthan Eye Centre, Jaipur'},
  ];

  // ─── MEDICAL HISTORY (TIMELINE) ───────────────────────────────────────────
  static const List<Map<String, String>> history = [
    {'date': '14 Mar 2026', 'event': 'HbA1c 6.2%, Fasting Glucose 110 mg/dL', 'doctor': 'Dr. Meena Kapoor', 'category': 'Labs'},
    {'date': '28 Feb 2026', 'event': 'TSH 3.8 uIU/mL — Normal thyroid function', 'doctor': 'Dr. Suresh Kumar', 'category': 'Labs'},
    {'date': '15 Feb 2026', 'event': 'Prescribed Amlodipine 5mg for Hypertension', 'doctor': 'Dr. Suresh Kumar', 'category': 'Prescriptions'},
    {'date': '10 Jan 2026', 'event': 'Diabetic Retinopathy Screening — Normal', 'doctor': 'Dr. Anjali Mehta', 'category': 'Reports'},
    {'date': '15 Dec 2025', 'event': 'Lipid Profile — Total Cholesterol 185 mg/dL', 'doctor': 'Dr. Meena Kapoor', 'category': 'Labs'},
    {'date': '05 Nov 2025', 'event': 'ECG — Normal sinus rhythm', 'doctor': 'Dr. Suresh Kumar', 'category': 'Reports'},
    {'date': '20 Sep 2025', 'event': 'Started Metformin 500mg for Diabetes', 'doctor': 'Dr. Suresh Kumar', 'category': 'Prescriptions'},
    {'date': '10 Aug 2025', 'event': 'Diagnosed with Type 2 Diabetes Mellitus', 'doctor': 'Dr. Suresh Kumar', 'category': 'Reports'},
  ];

  // ─── PROFILE MAP (for legacy SharedPreferences consumers) ─────────────────
  static Map<String, String> get profileMap => {
    'name': name,
    'abha': abhaNumber,
    'dob': dob,
    'mobile': mobile,
    'bloodGroup': bloodGroup,
    'allergies': allergiesShort,
    'emergencyContact': emergencyContact,
    'conditions': conditionsShort,
  };

  // ─── AI SYSTEM PROMPT CONTEXT ──────────────────────────────────────────────
  static String get aiContext => '''
PATIENT PERSONA:
- Name: $name
- Age: $age (DOB: $dob)
- Gender: $gender
- Blood Group: $bloodGroup
- ABHA: $abhaNumber
- Address: $address

CONDITIONS:
${conditions.map((c) => '- $c').join('\n')}

ALLERGIES:
${allergies.map((a) => '- $a (CRITICAL — do NOT suggest medications containing this)').join('\n')}

ACTIVE MEDICATIONS:
${medications.map((m) => '- ${m['name']} ${m['dosage']} — ${m['frequency']} (for ${m['for']})').join('\n')}

LATEST VITALS:
${vitals.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

PRIMARY PHYSICIAN:
- ${primaryPhysician['name']} (${primaryPhysician['specialty']})
- ${primaryPhysician['hospital']}
- Phone: ${primaryPhysician['phone']}

MEDICAL HISTORY (most recent first):
${history.map((h) => '- [${h['date']}] ${h['event']} — ${h['doctor']}').join('\n')}

EMERGENCY CONTACT:
- $emergencyRelation — $emergencyPhone
''';
}
