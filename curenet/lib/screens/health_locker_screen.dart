import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';

class HealthLockerScreen extends StatelessWidget {
  const HealthLockerScreen({super.key});

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
                colors: [Color(0xFF6B4E9B), Color(0xFF9F7AEA)],
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
                        "Health Locker 🛡️",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      Text(
                        "Your secure, encrypted vault",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
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
                  // Security Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8F7F7), Color(0xFFF0F8FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00A3A3).withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, color: Color(0xFF00A3A3), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Your data is encrypted with Zero-Knowledge proofs. No one can access without your consent. DPDP Act 2023 compliant.",
                            style: TextStyle(fontSize: 13, color: Color(0xFF00A3A3)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Records in Locker
                  const Text(
                    "RECORDS IN LOCKER",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9BA8BB),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Encrypted Record Cards
                  _lockerCard(
                    icon: "🧪",
                    title: "Blood Test Report",
                    date: "22 Feb 2026",
                    status: "Encrypted",
                    onTap: () {},
                  ),
                  _lockerCard(
                    icon: "💊",
                    title: "Prescription - Hypertension",
                    date: "18 Feb 2026",
                    status: "Encrypted",
                    onTap: () {},
                  ),
                  _lockerCard(
                    icon: "🩻",
                    title: "Chest X-Ray",
                    date: "05 Feb 2026",
                    status: "Encrypted",
                    onTap: () {},
                  ),
                  _lockerCard(
                    icon: "❤️",
                    title: "ECG Report",
                    date: "15 Jan 2026",
                    status: "Encrypted",
                    onTap: () {},
                  ),

                  const SizedBox(height: 24),

                  // Backup & Export
                  _buildActionCard(
                    icon: "💾",
                    title: "Backup All Records",
                    subtitle: "Download encrypted backup to your device",
                    color: const Color(0xFF00A3A3),
                    onTap: () => _showBackupDialog(context),
                  ),

                  _buildActionCard(
                    icon: "📤",
                    title: "Export to ABDM",
                    subtitle: "Share with other ABDM apps (HIP push)",
                    color: const Color(0xFF22A36A),
                    onTap: () => _showExportDialog(context),
                  ),

                  const SizedBox(height: 20),
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

  Widget _lockerCard({
    required String icon,
    required String title,
    required String date,
    required String status,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8DDE6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Locked",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF22A36A)),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.lock_outline, size: 18, color: Color(0xFF9BA8BB)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(icon, style: TextStyle(fontSize: 24, color: color))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF5A6880))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9BA8BB)),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Backup Records"),
        content: const Text("Encrypted backup will be downloaded to your device. Available offline forever."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Backup downloaded to Downloads"), backgroundColor: Color(0xFF00A3A3)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A3A3)),
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Export to ABDM"),
        content: const Text("Your records will be pushed to the national ABDM network for secure sharing with other apps."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Records exported to ABDM"), backgroundColor: Color(0xFF22A36A)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22A36A)),
            child: const Text("Export"),
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