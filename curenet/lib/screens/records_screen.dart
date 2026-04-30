import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import '../core/data_mode.dart';
import '../core/persona.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int activeTab = 0;
  final List<String> tabs = ["All", "Trends", "Prescriptions", "Labs", "Reports"];
  List<Map<String, dynamic>> allRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    DataMode.isDemo.addListener(_loadRecords);
  }

  @override
  void dispose() {
    DataMode.isDemo.removeListener(_loadRecords);
    super.dispose();
  }

  Future<void> _loadRecords() async {
    if (DataMode.isDemo.value) {
      // DEMO MODE: Hardcoded Priya Sharma records
      allRecords = [
        {
          "title": "HbA1c & Blood Glucose",
          "date": "14 Mar 2026",
          "doctor": "Dr. Meena Kapoor",
          "type": "science",
          "color": "#00A3A3",
          "category": "Labs",
          "value": 6.2,
          "unit": "%",
          "marker": "Glucose",
          "summary": "HbA1c is 6.2% (Pre-diabetic range). Fasting glucose is 110 mg/dL. Management required."
        },
        {
          "title": "Thyroid Profile (TSH)",
          "date": "28 Feb 2026",
          "doctor": "Dr. Suresh Kumar",
          "type": "science",
          "color": "#E07B39",
          "category": "Labs",
          "value": 3.8,
          "unit": "uIU/mL",
          "marker": "TSH",
          "summary": "TSH is 3.8 uIU/mL. Within normal range (0.4 - 4.0)."
        },
        {
          "title": "Prescription: Amlodipine",
          "date": "15 Feb 2026",
          "doctor": "Dr. Suresh Kumar",
          "type": "medication",
          "color": "#E07B39",
          "category": "Prescriptions",
          "summary": "Prescribed Amlodipine 5mg for Hypertension. Take once daily after breakfast."
        },
        {
          "title": "Prescription: Metformin",
          "date": "20 Sep 2025",
          "doctor": "Dr. Suresh Kumar",
          "type": "medication",
          "color": "#E07B39",
          "category": "Prescriptions",
          "summary": "Prescribed Metformin 500mg for Type 2 Diabetes. Twice daily after meals."
        },
        {
          "title": "Diabetic Retinopathy Screening",
          "date": "10 Jan 2026",
          "doctor": "Dr. Anjali Mehta",
          "type": "medical_services",
          "color": "#6B4E9B",
          "category": "Reports",
          "summary": "Routine eye checkup. No signs of retinopathy detected. Vision stable."
        },
        {
          "title": "Lipid Profile",
          "date": "15 Dec 2025",
          "doctor": "Dr. Meena Kapoor",
          "type": "science",
          "color": "#00A3A3",
          "category": "Labs",
          "value": 185,
          "unit": "mg/dL",
          "marker": "Cholesterol",
          "summary": "Total Cholesterol: 185 mg/dL. LDL: 110 mg/dL. HDL: 52 mg/dL. Good control."
        },
        {
          "title": "ECG Report - Normal",
          "date": "05 Nov 2025",
          "doctor": "Dr. Suresh Kumar",
          "type": "favorite",
          "color": "#D63B3B",
          "category": "Reports",
          "summary": "Resting ECG shows normal sinus rhythm. No significant ST-T changes."
        },
        {
          "title": "Prescription: Atorvastatin",
          "date": "15 Dec 2025",
          "doctor": "Dr. Meena Kapoor",
          "type": "medication",
          "color": "#E07B39",
          "category": "Prescriptions",
          "summary": "Prescribed Atorvastatin 10mg for Cholesterol. Once daily at night."
        },
      ];
    } else {
      // LIVE MODE: Read from SharedPreferences (real uploads)
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString('health_records');
      if (savedData != null) {
        allRecords = List<Map<String, dynamic>>.from(
          (jsonDecode(savedData) as List).map((e) => Map<String, dynamic>.from(e)),
        );
      } else {
        allRecords = [];
      }
    }
    if (mounted) setState(() => _isLoading = false);
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

  Widget _buildTrendsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartCard("Diabetes (HbA1c/Glucose)", "mmol/L", [5.8, 6.2, 5.2], ["Jan", "Feb", "Mar"]),
          const SizedBox(height: 20),
          _buildChartCard("Thyroid (TSH Level)", "uIU/mL", [4.5, 4.1, 3.8], ["Jan", "Feb", "Mar"]),
          const SizedBox(height: 20),
          _buildChartCard("Blood Pressure (Systolic)", "mmHg", [142, 138, 135], ["Jan", "Feb", "Mar"]),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String unit, List<double> values, List<String> labels) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0D2240))),
              Text("${values.last} $unit", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00A3A3))),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: const Color(0xFF00A3A3),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00A3A3).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((l) => Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)))).toList(),
          ),
        ],
      ),
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
              : currentTab == "Trends"
                ? _buildTrendsView()
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