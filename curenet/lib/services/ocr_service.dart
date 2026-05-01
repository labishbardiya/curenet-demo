import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/data_mode.dart';

class OcrService {
  static const String _storageKey = 'curenet_saved_records';

  /// Save a processed scan result to local storage.
  /// This stores the full uiData + fhirBundle so the rendered view
  /// can be re-opened later from Records or Health Locker.
  static Future<String> saveRecordLocally(Map<String, dynamic> recordData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      List<String> recordsList = prefs.getStringList(_storageKey) ?? [];
      
      final uiData = recordData['uiData'] as Map<String, dynamic>? ?? {};
      final abdmContext = recordData['abdmContext'] as Map<String, dynamic>? ?? {};
      final summary = uiData['summary'] as Map<String, dynamic>? ?? {};
      final docType = uiData['document_type'] ?? 'other';
      
      final String localId = DateTime.now().millisecondsSinceEpoch.toString();

      // Build a display-friendly record entry
      final recordToSave = {
        // Full data for re-opening rendered view
        'uiData': uiData,
        'fhirBundle': recordData['fhirBundle'],
        'abdmContext': abdmContext,
        'imagePath': recordData['imagePath'],
        // Searchable/display metadata
        'title': _generateTitle(uiData, abdmContext),
        'doctor': summary['doctor'] ?? abdmContext['doctorName'] ?? 'Unknown',
        'date': summary['date'] ?? DateTime.now().toIso8601String().split('T')[0],
        'displayDate': _formatDisplayDate(summary['date']),
        'documentType': docType,  // prescription, lab_report, or other
        'category': _docTypeToCategory(docType),
        'savedAt': DateTime.now().toIso8601String(),
        'localId': localId,
        'savedToLocker': false,
        // Extract lab values for trends
        'labValues': _extractLabValues(uiData),
      };
      
      recordsList.insert(0, jsonEncode(recordToSave));
      await prefs.setStringList(_storageKey, recordsList);
      
      // Also sync to health_records for backward compatibility
      await _syncToHealthRecords(prefs, recordToSave);

      return localId;
      
    } catch (e) {
      print('Error saving record locally: $e');
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Mark a record as saved to locker
  static Future<void> saveToLocker(String localId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recordsList = prefs.getStringList(_storageKey) ?? [];
      
      for (int i = 0; i < recordsList.length; i++) {
        final record = jsonDecode(recordsList[i]) as Map<String, dynamic>;
        if (record['localId'] == localId) {
          record['savedToLocker'] = true;
          recordsList[i] = jsonEncode(record);
          break;
        }
      }
      
      await prefs.setStringList(_storageKey, recordsList);
    } catch (e) {
      print('Error marking record for locker: $e');
    }
  }

  /// Remove a record from locker
  static Future<void> removeFromLocker(String localId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recordsList = prefs.getStringList(_storageKey) ?? [];
      
      for (int i = 0; i < recordsList.length; i++) {
        final record = jsonDecode(recordsList[i]) as Map<String, dynamic>;
        if (record['localId'] == localId) {
          record['savedToLocker'] = false;
          recordsList[i] = jsonEncode(record);
          break;
        }
      }
      
      await prefs.setStringList(_storageKey, recordsList);
    } catch (e) {
      print('Error removing record from locker: $e');
    }
  }

  /// Retrieve all saved records (full data including uiData/fhirBundle)
  static Future<List<Map<String, dynamic>>> getLocalRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recordsList = prefs.getStringList(_storageKey) ?? [];
      
      return recordsList.map((str) => jsonDecode(str) as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error retrieving local records: $e');
      return [];
    }
  }

  /// Get only records saved to locker
  static Future<List<Map<String, dynamic>>> getLockerRecords() async {
    final all = await getLocalRecords();
    return all.where((r) => r['savedToLocker'] == true).toList();
  }

  /// Get lab values for trends (from all lab reports)
  static Future<Map<String, List<Map<String, dynamic>>>> getLabTrends() async {
    final all = await getLocalRecords();
    final Map<String, List<Map<String, dynamic>>> trends = {};
    
    for (final record in all) {
      final labValues = record['labValues'] as Map<String, dynamic>? ?? {};
      final date = record['date'] ?? '';
      
      labValues.forEach((marker, value) {
        if (value != null && value is num) {
          trends.putIfAbsent(marker, () => []);
          trends[marker]!.add({
            'value': value.toDouble(),
            'date': date,
          });
        }
      });
    }
    
    return trends;
  }
  
  /// Clear all saved records (for debugging/testing)
  static Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove('health_records');
  }

  // ─── Private Helpers ───────────────────────────────────────────────

  static String _generateTitle(Map<String, dynamic> uiData, Map<String, dynamic> abdmContext) {
    final docType = uiData['document_type'] ?? 'other';
    final summary = uiData['summary'] as Map<String, dynamic>? ?? {};
    
    if (docType == 'prescription') {
      final meds = uiData['medications'] as List? ?? [];
      if (meds.isNotEmpty) {
        final firstMed = meds[0]['name'] ?? 'Medication';
        return meds.length > 1 
            ? 'Prescription: $firstMed +${meds.length - 1} more'
            : 'Prescription: $firstMed';
      }
      return 'Prescription';
    } else if (docType == 'lab_report') {
      final labs = uiData['lab_results'] as List? ?? [];
      if (labs.isNotEmpty) {
        return 'Lab Report: ${labs[0]['test_name'] ?? 'Test'}';
      }
      return 'Lab Report';
    }
    
    final patientName = abdmContext['patientName'] ?? summary['patient'] ?? '';
    return patientName.isNotEmpty ? 'Clinical Record — $patientName' : 'Medical Document';
  }

  static String _docTypeToCategory(String docType) {
    switch (docType) {
      case 'prescription': return 'Prescriptions';
      case 'lab_report': return 'Labs';
      default: return 'Reports';
    }
  }

  static String _formatDisplayDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      final now = DateTime.now();
      return '${now.day} ${_monthName(now.month)} ${now.year}';
    }
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final month = int.tryParse(parts[1]) ?? 1;
        return '${parts[2]} ${_monthName(month)} ${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Extract numeric lab values for trend tracking
  static Map<String, dynamic> _extractLabValues(Map<String, dynamic> uiData) {
    final labResults = uiData['lab_results'] as List? ?? [];
    final Map<String, dynamic> values = {};
    
    for (final lab in labResults) {
      final name = (lab['test_name'] ?? '').toString().toLowerCase();
      final value = lab['value'];
      
      if (value == null) continue;
      final numVal = value is num ? value : num.tryParse(value.toString());
      if (numVal == null) continue;
      
      // Map common lab tests to standardized marker names
      if (name.contains('hba1c') || name.contains('glycated')) {
        values['HbA1c'] = numVal;
      } else if (name.contains('glucose') || name.contains('sugar') || name.contains('rbs') || name.contains('fbs')) {
        values['Glucose'] = numVal;
      } else if (name.contains('tsh') || name.contains('thyroid')) {
        values['TSH'] = numVal;
      } else if (name.contains('cholesterol') || name.contains('lipid')) {
        values['Cholesterol'] = numVal;
      } else if (name.contains('hemoglobin') || name.contains('hb') || name.contains('haemoglobin')) {
        values['Hemoglobin'] = numVal;
      } else if (name.contains('creatinine')) {
        values['Creatinine'] = numVal;
      } else {
        // Store other values by their test name
        values[lab['test_name'] ?? name] = numVal;
      }
    }
    
    return values;
  }

  /// Sync to the `health_records` key used by RecordsScreen in live mode
  static Future<void> _syncToHealthRecords(SharedPreferences prefs, Map<String, dynamic> record) async {
    try {
      final String? existingData = prefs.getString('health_records');
      List<Map<String, dynamic>> healthRecords = [];
      
      if (existingData != null) {
        healthRecords = List<Map<String, dynamic>>.from(
          (jsonDecode(existingData) as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
      
      final docType = record['documentType'] ?? 'other';
      
      healthRecords.insert(0, {
        'title': record['title'],
        'date': record['displayDate'],
        'doctor': record['doctor'],
        'type': docType == 'prescription' ? 'medication' 
              : docType == 'lab_report' ? 'science' 
              : 'medical_services',
        'color': docType == 'prescription' ? '#E07B39' 
               : docType == 'lab_report' ? '#00A3A3' 
               : '#6B4E9B',
        'category': record['category'],
        'localId': record['localId'],
        'summary': record['doctor'] != null ? 'Processed by ${record['doctor']}' : 'Auto-processed via OCR',
      });
      
      await prefs.setString('health_records', jsonEncode(healthRecords));
    } catch (e) {
      print('Error syncing to health_records: $e');
    }
  }

  /// Retrieve all saved records from the backend MongoDB (Production DB)
  static Future<List<Map<String, dynamic>>> getBackendRecords() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.ocrApiUrl.replaceAll('/ocr', '')}/records/all'))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('Error fetching backend records: $e');
      return [];
    }
  }

  /// Get unified records based on DataMode
  static Future<List<Map<String, dynamic>>> getUnifiedRecords() async {
    if (DataMode.isDemo.value) {
      return getLocalRecords();
    } else {
      return getBackendRecords();
    }
  }
}
