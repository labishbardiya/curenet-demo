import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';

class AccessRequestScreen extends StatelessWidget {
  const AccessRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Amber Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE07B39), Color(0xFFC9601A)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Access Request 🔔",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      Text(
                        "A doctor wants to view your records",
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Doctor Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD8DDE6)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3A8A).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(child: Text("👨‍⚕️", style: TextStyle(fontSize: 28))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Dr. Suresh Kumar",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                "MBBS, MD · Apollo Spectra",
                                style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "✓ Verified NMC Doctor",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF22A36A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // They WILL see
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "✅ THEY WILL SEE",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3), letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 10),
                        _permissionRow("3-line AI summary of your health"),
                        _permissionRow("List of past visits (dates only)"),
                        _permissionRow("Current medications"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // They WILL NOT see
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD63B3B).withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🚫 THEY WILL NOT SEE",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD63B3B), letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 10),
                        _permissionRow("Full prescription details", isRed: true),
                        _permissionRow("Lab report values & images", isRed: true),
                        _permissionRow("Personal notes & emergency contacts", isRed: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    "Access expires in 30 minutes after approval",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Approve Button
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/access-ok'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "✓ Approve Access",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Deny Button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD63B3B),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "✗ Deny Access",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation
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
            _navItem("📋", "Records", false, () => Navigator.pushReplacementNamed(context, '/records')),
            _navItem("📲", "Share", false, () => Navigator.pushReplacementNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  Widget _permissionRow(String text, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            isRed ? "✗" : "✓",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isRed ? const Color(0xFFD63B3B) : const Color(0xFF22A36A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0D2240)),
            ),
          ),
        ],
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
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
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