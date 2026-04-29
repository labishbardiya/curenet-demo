import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int activeTab = 0;
  final List<String> tabs = ["All", "Prescriptions", "Labs", "Reports"];
  List<Map<String, dynamic>> allRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('health_records');
    
    if (recordsJson != null && recordsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(recordsJson);
      setState(() {
        allRecords = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      // Initial dummy data
      allRecords = [
        {"title": "Blood Test Report", "date": "22 Feb 2026", "doctor": "Dr. Meena Kapoor", "type": "science", "color": "#00A3A3", "category": "Labs"},
        {"title": "Prescription - Hypertension", "date": "18 Feb 2026", "doctor": "Dr. Suresh Kumar", "type": "medication", "color": "#E07B39", "category": "Prescriptions"},
        {"title": "Chest X-Ray", "date": "05 Feb 2026", "doctor": "Dr. Anjali Mehta", "type": "medical_services", "color": "#6B4E9B", "category": "Reports"},
        {"title": "Lipid Profile", "date": "28 Jan 2026", "doctor": "Dr. Meena Kapoor", "type": "science", "color": "#00A3A3", "category": "Labs"},
        {"title": "ECG Report", "date": "15 Jan 2026", "doctor": "Dr. Suresh Kumar", "type": "favorite", "color": "#D63B3B", "category": "Reports"},
      ];
      _saveRecords();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('health_records', jsonEncode(allRecords));
  }

  void _addSimulatedRecord() {
    final now = DateTime.now();
    final dateStr = "${now.day} ${_getMonth(now.month)} ${now.year}";
    
    final newRecord = {
      "title": "Manual Upload #${allRecords.length + 1}",
      "date": dateStr,
      "doctor": "Self Uploaded",
      "type": "upload_file",
      "color": "#0D2240",
      "category": "Reports"
    };

    setState(() {
      allRecords.insert(0, newRecord);
    });
    _saveRecords();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: TranslatedText("✅ New record added successfully"), backgroundColor: Color(0xFF00A3A3)),
    );
  }

  String _getMonth(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'science': return Icons.science;
      case 'medication': return Icons.medication;
      case 'medical_services': return Icons.medical_services;
      case 'favorite': return Icons.favorite;
      case 'upload_file': return Icons.upload_file;
      default: return Icons.description;
    }
  }

  void _deleteRecord(int index) {
    setState(() {
      allRecords.removeAt(index);
    });
    _saveRecords();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: TranslatedText("Record deleted"), backgroundColor: Color(0xFFD63B3B)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentTab = tabs[activeTab];
    final filteredRecords = currentTab == "All" 
        ? allRecords 
        : allRecords.where((r) => r['category'] == currentTab).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFD8DDE6))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                ),
                const SizedBox(width: 12),
                const TranslatedText("Health Records",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF0D2240)),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final isActive = index == activeTab;
                return GestureDetector(
                  onTap: () => setState(() => activeTab = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isActive
                          ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: TranslatedText(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Records List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredRecords.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const TranslatedText("No records found in this category", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];
                      final originalIndex = allRecords.indexOf(record);
                      final speakText = '${record['title']}. By ${record['doctor']}. ${record['date']}.';
                      return Dismissible(
                        key: Key(record['title'] + record['date']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: const Color(0xFFD63B3B),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _deleteRecord(originalIndex),
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Opened ${record['title']}"),
                                backgroundColor: const Color(0xFF00A3A3),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFD8DDE6)),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 22),
                                  onPressed: () async {
                                    final ok = await VoiceHelper.speak(speakText);
                                    if (!ok && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(VoiceHelper.lastError ?? 'Voice readout failed.'),
                                          backgroundColor: const Color(0xFF0D2240),
                                        ),
                                      );
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(record['color']!.replaceFirst('#', '0xFF'))),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(_getIcon(record['type'] as String), size: 24, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TranslatedText(
                                        record['title']!,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                      ),
                                      TranslatedText(
                                        record['doctor']!,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      record['date']!,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF00A3A3)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Upload Button (floating style)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: _addSimulatedRecord,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2240),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  TranslatedText("Upload New Record",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation (active on Records)
      bottomNavigationBar: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, "Home", false, () => Navigator.pushReplacementNamed(context, '/home')),
            _navItem(Icons.smart_toy, "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
            _scanButton(context),
            _navItem(Icons.list_alt, "Records", true, null),
            _navItem(Icons.share, "Share", false, () => Navigator.pushNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
          TranslatedText(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/doc-scan'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00A3A3), Color(0xFF00C4C4)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  SizedBox(height: 2),
                  TranslatedText("SCAN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}