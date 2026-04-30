import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OcrService {
  static const String _storageKey = 'curenet_saved_records';

  // Save a processed record to local storage
  static Future<void> saveRecordLocally(Map<String, dynamic> recordData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing records
      List<String> recordsList = prefs.getStringList(_storageKey) ?? [];
      
      // Add a timestamp and unique ID if not present
      final recordToSave = {
        ...recordData,
        'savedAt': DateTime.now().toIso8601String(),
        'localId': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      // Add new record to the beginning of the list
      recordsList.insert(0, jsonEncode(recordToSave));
      
      // Save back to SharedPreferences
      await prefs.setStringList(_storageKey, recordsList);
      print('Record saved locally successfully.');
    } catch (e) {
      print('Error saving record locally: $e');
    }
  }

  // Retrieve all saved records
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
  
  // Clear all saved records (for debugging/testing)
  static Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
