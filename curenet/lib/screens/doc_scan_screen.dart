import 'package:flutter/material.dart';
import '../core/theme.dart';

class DocScanScreen extends StatefulWidget {
  const DocScanScreen({super.key});

  @override
  State<DocScanScreen> createState() => _DocScanScreenState();
}

class _DocScanScreenState extends State<DocScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.15, end: 0.80).animate(_scanController);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D2240), Color(0xFF1A3A5C)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Scan & Upload",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      "Scan prescriptions, reports & documents",
                      style: TextStyle(fontSize: 12, color: Color(0xFF00C4C4)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Camera Viewfinder with animated scan line
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      color: const Color(0xFF050F1A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF00A3A3), width: 3),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Corner brackets
                        Positioned(top: 12, left: 12, child: _cornerBracket()),
                        Positioned(top: 12, right: 12, child: _cornerBracket(rotate: true)),
                        Positioned(bottom: 12, left: 12, child: _cornerBracket(rotate: true, bottom: true)),
                        Positioned(bottom: 12, right: 12, child: _cornerBracket(bottom: true)),

                        // Animated scan line
                        AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: _scanAnimation.value * 220 + 20,
                              left: 20,
                              right: 20,
                              child: Container(
                                height: 2,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Color(0xFF00A3A3), Colors.transparent],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("📷", style: TextStyle(fontSize: 48, color: Colors.white54)),
                            SizedBox(height: 8),
                            Text(
                              "Camera Active",
                              style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Instruction card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00A3A3).withOpacity(0.15)),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          "📄 Point camera at document",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Align your prescription, lab report, or QR code within the frame. The document will be saved to your Health Locker automatically.",
                          style: TextStyle(fontSize: 13, color: Color(0xFF5A6880), height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // What you can scan
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "WHAT YOU CAN SCAN",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB), letterSpacing: 0.4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _scanItem("💊", "Prescriptions & Medicines"),
                  _scanItem("🧪", "Lab Reports & Blood Tests"),
                  _scanItem("🩻", "X-Ray & Radiology Reports"),
                  _scanItem("📲", "Doctor's ABHA QR Code"),

                  const SizedBox(height: 32),

                  // Simulate Scan Button
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ Document scanned & saved to Health Locker!"),
                          backgroundColor: Color(0xFF00A3A3),
                        ),
                      );
                      Future.delayed(const Duration(seconds: 1), () {
                        Navigator.pushNamed(context, '/records');
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "📷 Scan Document (Simulate)",
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

  Widget _scanItem(String emoji, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cornerBracket({bool rotate = false, bool bottom = false}) {
    return Transform.rotate(
      angle: rotate ? (bottom ? 1.57 : -1.57) : 0,
      child: const Icon(Icons.square_outlined, size: 28, color: Color(0xFF00A3A3)),
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
      onTap: () {}, // Already on this screen
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