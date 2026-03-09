import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import 'package:curenet/core/navigation_helper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Navy Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 22),
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
                const TranslatedText(
                  "My Profile",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),

          // Profile Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A3A3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text("P", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      TranslatedText(
                        "Priya Sharma",
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                      ),
                      Text(
                        "ABHA: 91-2345-6789-0123",
                        style: TextStyle(fontSize: 13, color: Color(0xFF00C4C4)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 24),
                  onPressed: () async {
                    final ok = await VoiceHelper.speak(
                      "Priya Sharma. ABHA number 91-2345-6789-0123.",
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(VoiceHelper.lastError ?? 'Voice readout failed.'),
                          backgroundColor: const Color(0xFF0D2240),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Health Information Card
                  _buildCard(
                    title: "HEALTH INFORMATION",
                    children: [
                      _infoRow("Date of Birth", "14 Mar 1985"),
                      _infoRow("Mobile", "+91 98765 43210"),
                      _infoRow("Blood Group", "B+"),
                      _infoRow("ABHA Number", "91-2345-6789-0123"),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Doctor Access Log
                  _buildCard(
                    title: "DOCTOR ACCESS LOG",
                    children: [
                      _accessRow("Dr. Suresh Kumar", "Apollo Spectra · Today 11:41 AM", "Active"),
                      const Divider(height: 1, color: Color(0xFFD8DDE6)),
                      _accessRow("Dr. Meena Kapoor", "Apollo Spectra · 22 Feb 2026", "Expired"),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Settings
                  _buildCard(
                    title: "SETTINGS",
                    children: [
                      _settingRow("Notification Preferences", () {}),
                      _settingRow("Download Health Records", () {}),
                      _settingRow("Privacy Policy & DPDP Act", () => Navigator.pushNamed(context, '/privacy-policy')),
                      _settingRow("🛠 Edge Cases (Debug)", () => Navigator.pushNamed(context, '/edge'), isRed: false),
                    ],
                  ),

                  const SizedBox(height: 40),
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

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF5A6880))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D2240))),
        ],
      ),
    );
  }

  Widget _accessRow(String doctor, String subtitle, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: status == "Active" ? const Color(0xFFE6F7EF) : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: status == "Active" ? const Color(0xFF22A36A) : const Color(0xFF9BA8BB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(String title, VoidCallback onTap, {bool isRed = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD8DDE6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isRed ? const Color(0xFFD63B3B) : const Color(0xFF0D2240),
              ),
            ),
            const Text("›", style: TextStyle(fontSize: 18, color: Color(0xFF9BA8BB))),
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