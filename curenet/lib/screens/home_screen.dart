import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';

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
                          child: Text("P", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
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
                Text(
                  "Good morning, Priya 👋",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ABHAy AI Big Card (clickable)
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
                        child: const Center(child: Text("🤖", style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ask Abhya AI",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            Text(
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
                    child: const Text(
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
                _quickAction(context, "📋", "Records", '/records'),
                _quickAction(context, "📲", "Share QR", '/qr-share'),
                _quickAction(context, "📷", "Scan Doc", '/doc-scan'),
                _quickAction(context, "🔐", "Locker", '/health-locker'),
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
                Text("Recent Records", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240))),
                Text("View all →", style: TextStyle(fontSize: 13, color: Color(0xFF00A3A3), fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sample Records (horizontal scroll)
          SizedBox(
            height: 110,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                _recordCard("Blood Test", "22 Feb 2026", "🧪"),
                const SizedBox(width: 12),
                _recordCard("Prescription", "18 Feb 2026", "💊"),
                const SizedBox(width: 12),
                _recordCard("X-Ray", "05 Feb 2026", "🩻"),
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
                _bottomNavItem("🏠", "Home", true),
                _bottomNavItem("🤖", "ABHAy", false, onTap: () => Navigator.pushNamed(context, '/chat')),
                _scanButton(context),
                _bottomNavItem("📋", "Records", false, onTap: () => Navigator.pushNamed(context, '/records')),
                _bottomNavItem("📲", "Share", false, onTap: () => Navigator.pushNamed(context, '/qr-share')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(BuildContext context, String emoji, String label, String route) {
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
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5A6880))),
        ],
      ),
    );
  }

  Widget _recordCard(String title, String date, String emoji) {
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
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF9BA8BB))),
        ],
      ),
    );
  }

  Widget _bottomNavItem(String icon, String label, bool isActive, {VoidCallback? onTap}) {
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
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
          ),
          Text(
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
                  Text("📷", style: TextStyle(fontSize: 20, color: Colors.white)),
                  Text("SCAN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const Text("Scan", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF00A3A3))),
        ],
      ),
    );
  }
}