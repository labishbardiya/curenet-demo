/// ─── CureNet Demo Persona ──────────────────────────────────────────────────
/// Single source of truth for Arjun Kumar's clinical profile.
/// Used by: HomeScreen, ProfileScreen, RecordsScreen, EmergencySnapshotScreen,
///          AiService, ChatScreen.
///
/// In production this class would be populated from ABDM profile API + local vault.

class Persona {
  // ─── IDENTITY ──────────────────────────────────────────────────────────────
  static const String name = 'Arjun Kumar';
  static const String abhaNumber = '91-4567-8901-2345';
  static const String abhaAddress = 'arjun.kumar@abdm';
  static const String dob = '12 Aug 1979';
  static const int age = 45;
  static const String gender = 'Male';
  static const String bloodGroup = 'O+';
  static const String mobile = '+91 95099 58988';
  static const String email = 'arjun.kumar@gmail.com';
  static const String address = 'Flat 402, Sunshine Apts, HSR Layout, Bengaluru 560102';

  // ─── EMERGENCY INFO ────────────────────────────────────────────────────────
  static const String emergencyContact = '+91 95099 58989 (Sneha Kumar - Wife)';
  static const String emergencyPhone = '+91 95099 58989';
  static const String emergencyRelation = 'Sneha Kumar (Wife)';
  static const String insuranceId = 'PMJAY-KA-20240092';

  // ─── MEDICAL CONDITIONS ────────────────────────────────────────────────────
  static const List<String> conditions = [
    'Essential Hypertension (Since 2022)',
    'Hyperlipidemia (High Cholesterol) (Since 2023)',
    'Mild Fatty Liver (Grade 1)',
  ];
  static const String conditionsShort = 'Hypertension, High Cholesterol';

  // ─── ALLERGIES ─────────────────────────────────────────────────────────────
  static const List<String> allergies = ['Sulfa Drugs', 'Dust Mites'];
  static const String allergiesShort = 'Sulfa Drugs, Dust';

  // ─── ACTIVE MEDICATIONS ────────────────────────────────────────────────────
  static const List<Map<String, String>> medications = [
    {'name': 'Telmisartan', 'dosage': '40mg', 'frequency': 'Once daily (morning)', 'for': 'Hypertension'},
    {'name': 'Atorvastatin', 'dosage': '20mg', 'frequency': 'Once daily (night)', 'for': 'Cholesterol'},
    {'name': 'Fish Oil', 'dosage': '1000mg', 'frequency': 'Once daily', 'for': 'Heart Health'},
  ];

  // ─── LATEST VITALS ─────────────────────────────────────────────────────────
  static const Map<String, String> vitals = {
    'Blood Pressure': '132/84 mmHg',
    'Total Cholesterol': '210 mg/dL',
    'LDL': '145 mg/dL (High)',
    'HDL': '42 mg/dL',
    'Triglycerides': '180 mg/dL',
    'HbA1c': '5.8% (Normal)',
    'BMI': '27.2 (Overweight)',
    'Weight': '82 kg',
    'Height': '174 cm',
  };

  // ─── PHYSICIANS ────────────────────────────────────────────────────────────
  static const Map<String, String> primaryPhysician = {
    'name': 'Dr. Rajesh Mehta',
    'specialty': 'Cardiologist',
    'hospital': 'Manipal Hospital, Bengaluru',
    'phone': '+91 80234 56789',
  };

  static const List<Map<String, String>> doctors = [
    {'name': 'Dr. Rajesh Mehta', 'specialty': 'Cardiology', 'hospital': 'Manipal Hospital'},
    {'name': 'Dr. Kavita Rao', 'specialty': 'General Physician', 'hospital': 'Cloudnine Clinics'},
    {'name': 'Dr. Vikram Shah', 'specialty': 'Gastroenterologist', 'hospital': 'Aster CMI'},
  ];

  // ─── MEDICAL HISTORY (TIMELINE) ───────────────────────────────────────────
  static const List<Map<String, String>> history = [
    {'date': '20 Apr 2026', 'event': 'Lipid Profile — Total Cholesterol 210 mg/dL', 'doctor': 'Dr. Rajesh Mehta', 'category': 'Labs'},
    {'date': '15 Mar 2026', 'event': 'Follow-up for Hypertension — BP 132/84', 'doctor': 'Dr. Rajesh Mehta', 'category': 'Reports'},
    {'date': '10 Feb 2026', 'event': 'Liver Function Test — Mild elevation in ALT', 'doctor': 'Dr. Vikram Shah', 'category': 'Labs'},
    {'date': '15 Jan 2026', 'event': 'Annual Physical — HbA1c 5.8%', 'doctor': 'Dr. Kavita Rao', 'category': 'Labs'},
    {'date': '05 Dec 2025', 'event': 'USG Abdomen — Grade 1 Fatty Liver', 'doctor': 'Dr. Vikram Shah', 'category': 'Reports'},
    {'date': '20 Oct 2025', 'event': 'Prescribed Atorvastatin 20mg for Lipid control', 'doctor': 'Dr. Rajesh Mehta', 'category': 'Prescriptions'},
    {'date': '10 Aug 2025', 'event': 'Treadmill Test (TMT) — Negative for Ischemia', 'doctor': 'Dr. Rajesh Mehta', 'category': 'Reports'},
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
