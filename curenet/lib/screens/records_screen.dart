import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import '../core/data_mode.dart';
import '../core/persona.dart';
import '../services/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'scan_result_screen.dart';

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
      allRecords = _demoRecords();
    } else {
      // LIVE MODE: Load real scanned records
      final records = await OcrService.getLocalRecords();
      allRecords = records.map((r) => {
        'title': r['title'] ?? 'Medical Document',
        'date': r['displayDate'] ?? r['date'] ?? '',
        'doctor': r['doctor'] ?? 'Unknown',
        'type': _categoryToType(r['category']),
        'color': _categoryToColor(r['category']),
        'category': r['category'] ?? 'Reports',
        'localId': r['localId'],
        'hasFullData': r['uiData'] != null,
        'uiData': r['uiData'],
        'fhirBundle': r['fhirBundle'],
        'abdmContext': r['abdmContext'],
        'labValues': r['labValues'],
        'imagePath': r['imagePath'],
        'summary': r['doctor'] != null ? 'Processed by ${r['doctor']}' : '',
      }).toList();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _categoryToType(String? cat) {
    switch (cat) {
      case 'Prescriptions': return 'medication';
      case 'Labs': return 'science';
      default: return 'medical_services';
    }
  }

  String _categoryToColor(String? cat) {
    switch (cat) {
      case 'Prescriptions': return '#E07B39';
      case 'Labs': return '#00A3A3';
      default: return '#6B4E9B';
    }
  }

  void _openRecord(Map<String, dynamic> record) {
    if (record['hasFullData'] == true && record['uiData'] != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          uiData: Map<String, dynamic>.from(record['uiData']),
          fhirBundle: Map<String, dynamic>.from(record['fhirBundle'] ?? {}),
          abdmContext: Map<String, dynamic>.from(record['abdmContext'] ?? {}),
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opened ${record['title']}"), backgroundColor: const Color(0xFF00A3A3)),
      );
    }
  }

  Future<void> _deleteRecord(int index) async {
    setState(() => allRecords.removeAt(index));
    if (!DataMode.isDemo.value) {
      final prefs = await SharedPreferences.getInstance();
      final records = await OcrService.getLocalRecords();
      if (index < records.length) {
        records.removeAt(index);
        await prefs.setStringList('curenet_saved_records',
          records.map((r) => jsonEncode(r)).toList());
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText("Record deleted"), backgroundColor: Color(0xFFD63B3B)),
      );
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'science': return Icons.science;
      case 'medication': return Icons.medication;
      case 'medical_services': return Icons.medical_services;
      case 'favorite': return Icons.favorite;
      default: return Icons.description;
    }
  }

  String _getMonth(int month) {
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return months[month - 1];
  }

  // ─── Trends View (functional with real data) ─────────────────────

  Widget _buildTrendsView() {
    if (DataMode.isDemo.value) return _buildDemoTrends();

    // Extract lab values from real records
    final Map<String, List<Map<String, dynamic>>> trends = {};
    for (final record in allRecords) {
      final labValues = record['labValues'] as Map<String, dynamic>? ?? {};
      final date = record['date'] ?? '';
      labValues.forEach((marker, value) {
        if (value != null && value is num) {
          trends.putIfAbsent(marker, () => []);
          trends[marker]!.add({'value': value.toDouble(), 'date': date});
        }
      });
    }

    if (trends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const TranslatedText("No lab data yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB))),
              const SizedBox(height: 8),
              const TranslatedText("Scan a lab report to see your health trends here.",
                style: TextStyle(fontSize: 14, color: Color(0xFF9BA8BB)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: trends.entries.map((entry) {
          final values = entry.value.map((e) => e['value'] as double).toList();
          final labels = entry.value.map((e) => (e['date'] as String).split('-').last).toList();
          final unit = _getUnitForMarker(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildChartCard(entry.key, unit, values, labels),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDemoTrends() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildChartCard("Diabetes (HbA1c)", "%", [6.8, 6.5, 6.2], ["Sep", "Dec", "Mar"]),
          const SizedBox(height: 20),
          _buildChartCard("Thyroid (TSH)", "uIU/mL", [4.5, 4.1, 3.8], ["Sep", "Dec", "Mar"]),
          const SizedBox(height: 20),
          _buildChartCard("Blood Pressure", "mmHg", [142, 138, 135], ["Sep", "Dec", "Mar"]),
          const SizedBox(height: 20),
          _buildChartCard("Cholesterol", "mg/dL", [210, 195, 185], ["Sep", "Dec", "Mar"]),
        ],
      ),
    );
  }

  String _getUnitForMarker(String marker) {
    final m = marker.toLowerCase();
    if (m.contains('hba1c')) return '%';
    if (m.contains('glucose') || m.contains('sugar')) return 'mg/dL';
    if (m.contains('tsh')) return 'uIU/mL';
    if (m.contains('cholesterol')) return 'mg/dL';
    if (m.contains('hemoglobin')) return 'g/dL';
    if (m.contains('creatinine')) return 'mg/dL';
    return '';
  }

  Widget _buildChartCard(String title, String unit, List<double> values, List<String> labels) {
    final trendDown = values.length >= 2 && values.last < values.first;
    final trendColor = trendDown ? const Color(0xFF22A36A) : const Color(0xFFE07B39);

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
              Expanded(child: TranslatedText(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendDown ? Icons.trending_down : Icons.trending_up, size: 16, color: trendColor),
                    const SizedBox(width: 4),
                    Text("${values.last} $unit", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: trendColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                  isCurved: true, color: const Color(0xFF00A3A3), barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF00A3A3).withValues(alpha: 0.1)),
                ),
              ],
            )),
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

  // ─── Demo Data ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _demoRecords() => [
    {"title": "HbA1c & Blood Glucose", "date": "14 Mar 2026", "doctor": "Dr. Meena Kapoor", "type": "science", "color": "#00A3A3", "category": "Labs", "labValues": {"HbA1c": 6.2, "Glucose": 110}, "summary": "HbA1c 6.2% (Pre-diabetic). Fasting glucose 110 mg/dL."},
    {"title": "Thyroid Profile (TSH)", "date": "28 Feb 2026", "doctor": "Dr. Suresh Kumar", "type": "science", "color": "#00A3A3", "category": "Labs", "labValues": {"TSH": 3.8}, "summary": "TSH 3.8 uIU/mL. Normal range."},
    {"title": "Prescription: Amlodipine", "date": "15 Feb 2026", "doctor": "Dr. Suresh Kumar", "type": "medication", "color": "#E07B39", "category": "Prescriptions", "summary": "Amlodipine 5mg for Hypertension."},
    {"title": "Prescription: Metformin", "date": "20 Sep 2025", "doctor": "Dr. Suresh Kumar", "type": "medication", "color": "#E07B39", "category": "Prescriptions", "summary": "Metformin 500mg for Type 2 Diabetes."},
    {"title": "Diabetic Retinopathy Screening", "date": "10 Jan 2026", "doctor": "Dr. Anjali Mehta", "type": "medical_services", "color": "#6B4E9B", "category": "Reports", "summary": "No signs of retinopathy."},
    {"title": "Lipid Profile", "date": "15 Dec 2025", "doctor": "Dr. Meena Kapoor", "type": "science", "color": "#00A3A3", "category": "Labs", "labValues": {"Cholesterol": 185}, "summary": "Total Cholesterol: 185 mg/dL. Good."},
    {"title": "ECG Report - Normal", "date": "05 Nov 2025", "doctor": "Dr. Suresh Kumar", "type": "favorite", "color": "#D63B3B", "category": "Reports", "summary": "Normal sinus rhythm."},
    {"title": "Prescription: Atorvastatin", "date": "15 Dec 2025", "doctor": "Dr. Meena Kapoor", "type": "medication", "color": "#E07B39", "category": "Prescriptions", "summary": "Atorvastatin 10mg for Cholesterol."},
  ];

  // ─── Build ─────────────────────────────────────────────────────────

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
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240)))),
                const SizedBox(width: 12),
                const TranslatedText("Health Records", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D2240))),
                const Spacer(),
                Text("${allRecords.length}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3))),
                const SizedBox(width: 4),
                const Text("records", style: TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
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
                      boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)] : [],
                    ),
                    alignment: Alignment.center,
                    child: TranslatedText(tabs[index],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
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
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        final originalIndex = allRecords.indexOf(record);
                        // Use localId for real records, or hashCode for demo/unsaved records to guarantee uniqueness
                        final uniqueKey = record['localId']?.toString() ?? record.hashCode.toString();
                        return Dismissible(
                          key: Key(uniqueKey),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: const Color(0xFFD63B3B), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteRecord(originalIndex),
                          child: _buildRecordCard(record),
                        );
                      },
                    ),
          ),
          // Scan button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/doc-scan'),
              icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
              label: const TranslatedText("Scan New Document", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A3A3),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const TranslatedText("No records found", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          const TranslatedText("Scan a document to get started", style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB))),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final hasData = record['hasFullData'] == true;
    return GestureDetector(
      onTap: () => _openRecord(record),
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
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Color(int.parse((record['color'] ?? '#00A3A3').replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(_getIcon(record['type'] ?? 'description'), size: 24, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(record['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(record['doctor'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(record['date'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
                const SizedBox(height: 4),
                Icon(hasData ? Icons.visibility : Icons.arrow_forward_ios,
                  size: 16, color: hasData ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 78,
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFD8DDE6)))),
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
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
        TranslatedText(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
      ]),
    );
  }

  Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/doc-scan'),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00A3A3), Color(0xFF00C4C4)]), borderRadius: BorderRadius.circular(18)),
          child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.camera_alt, size: 20, color: Colors.white),
            SizedBox(height: 2),
            TranslatedText("SCAN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          ])),
        ),
      ]),
    );
  }
}