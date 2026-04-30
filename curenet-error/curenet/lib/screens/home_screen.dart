import 'package:flutter/material.dart';
import '../core/translated_text.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Status bar simulation
          const SizedBox(height: 44),

          // Top Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A3A3),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Priya Sharma",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                          ),
                          Text(
                            "91-2345-6789-0123",
                            style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.translate, color: Color(0xFF0D2240)),
                  onPressed: () => Navigator.pushNamed(context, '/language-select'),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0D2240)),
                  onPressed: () => Navigator.pushNamed(context, '/notifications'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Welcome + Greeting
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: const [
                TranslatedText(
                  "Good morning, Priya",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ABHAy AI Big Card
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chat'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A3A3), Color(0xFF1A3A5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Icon(Icons.smart_toy, size: 28, color: Colors.white)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TranslatedText(
                              "Ask Abhya AI",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const TranslatedText(
                              "Anything about your health",
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const TranslatedText(
                      "What medications am I on right now?",
                      style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _quickAction(context, Icons.list_alt, "Records", '/records'),
                _quickAction(context, Icons.qr_code_scanner, "Share QR", '/qr-share'),
                _quickAction(context, Icons.document_scanner, "Scan Doc", '/doc-scan'),
                _quickAction(context, Icons.lock_rounded, "Locker", '/health-locker'),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Recent Records Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                TranslatedText("Recent Records", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240))),
                TranslatedText("View all →", style: TextStyle(fontSize: 13, color: Color(0xFF00A3A3), fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sample Records
          SizedBox(
            height: 110,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                _recordCard("Blood Test", "22 Feb 2026", Icons.science),
                const SizedBox(width: 12),
                _recordCard("Prescription", "18 Feb 2026", Icons.medication),
                const SizedBox(width: 12),
                _recordCard("X-Ray", "05 Feb 2026", Icons.medical_services),
              ],
            ),
          ),

          const Spacer(),



          // Bottom Navigation
          Container(
            height: 78,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bottomNavItem(Icons.home, "Home", true),
                _bottomNavItem(Icons.smart_toy, "ABHAy", false, onTap: () => Navigator.pushNamed(context, '/chat')),
                _scanButton(context),
                _bottomNavItem(Icons.list_alt, "Records", false, onTap: () => Navigator.pushNamed(context, '/records')),
                _bottomNavItem(Icons.share, "Share", false, onTap: () => Navigator.pushNamed(context, '/qr-share')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Your existing helper methods (unchanged)
  Widget _quickAction(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
            ),
            child: Center(child: Icon(icon, size: 24, color: const Color(0xFF00A3A3))),
          ),
          const SizedBox(height: 6),
          TranslatedText(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5A6880))),
        ],
      ),
    );
  }

  Widget _recordCard(String title, String date, IconData icon) {
    return Container(
      width: 118,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF0D2240)),
          const Spacer(),
          TranslatedText(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF9BA8BB))),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE8F7F7) : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(child: Icon(icon, size: 22, color: isActive ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
          ),
          TranslatedText(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB),
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
              boxShadow: [
                BoxShadow(color: const Color(0xFF00A3A3).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  SizedBox(height: 2),
                  Text("SCAN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const TranslatedText("Scan", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF00A3A3))),
        ],
      ),
    );
  }
}