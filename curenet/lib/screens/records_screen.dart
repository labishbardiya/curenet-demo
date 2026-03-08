import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int activeTab = 0;
  final List<String> tabs = ["All", "Recent", "Prescriptions", "Labs", "Reports"];

  final List<Map<String, String>> allRecords = [
    {"title": "Blood Test Report", "date": "22 Feb 2026", "doctor": "Dr. Meena Kapoor", "type": "🧪", "color": "#00A3A3"},
    {"title": "Prescription - Hypertension", "date": "18 Feb 2026", "doctor": "Dr. Suresh Kumar", "type": "💊", "color": "#E07B39"},
    {"title": "Chest X-Ray", "date": "05 Feb 2026", "doctor": "Dr. Anjali Mehta", "type": "🩻", "color": "#6B4E9B"},
    {"title": "Lipid Profile", "date": "28 Jan 2026", "doctor": "Dr. Meena Kapoor", "type": "🧪", "color": "#00A3A3"},
    {"title": "ECG Report", "date": "15 Jan 2026", "doctor": "Dr. Suresh Kumar", "type": "❤️", "color": "#D63B3B"},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRecords = allRecords; // In real app we would filter by tab

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
                const Text(
                  "Health Records",
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
                    child: Text(
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredRecords.length,
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                return GestureDetector(
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
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Color(int.parse(record['color']!.replaceFirst('#', '0xFF'))),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(record['type']!, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record['title']!,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              Text(
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
                );
              },
            ),
          ),

          // Upload Button (floating style)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/doc-scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2240),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("📷 ", style: TextStyle(fontSize: 20)),
                  Text(
                    "Upload New Record",
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
            _navItem("🏠", "Home", false, () => Navigator.pushReplacementNamed(context, '/home')),
            _navItem("🤖", "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
            _scanButton(context),
            _navItem("📋", "Records", true, null),
            _navItem("📲", "Share", false, () => Navigator.pushNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
          Text(
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
                  Text("📷", style: TextStyle(fontSize: 20, color: Colors.white)),
                  Text("SCAN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}