import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';

class EdgeCasesScreen extends StatefulWidget {
  const EdgeCasesScreen({super.key});

  @override
  State<EdgeCasesScreen> createState() => _EdgeCasesScreenState();
}

class _EdgeCasesScreenState extends State<EdgeCasesScreen> {
  bool _isOffline = false;
  bool _showError = false;
  String _errorMessage = '';

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
                colors: [Color(0xFFD63B3B), Color(0xFFB71C1C)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                const TranslatedText("Edge Cases",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),

          // Offline Banner
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD63B3B).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Color(0xFFD63B3B), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: TranslatedText("Offline Mode",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD63B3B)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _isOffline = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: TranslatedText("🟢 Connected"), backgroundColor: Color(0xFF22A36A)),
                      );
                    },
                    child: const TranslatedText("Reconnect", style: TextStyle(color: Color(0xFF22A36A))),
                  ),
                ],
              ),
            ),

          // Empty Records State
          if (!_showError)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Empty illustration
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_outlined, size: 48, color: Color(0xFF00A3A3)),
                            SizedBox(height: 12),
                            TranslatedText("No Records Yet",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const TranslatedText("Your Health Locker is empty",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                    ),
                    const SizedBox(height: 8),
                    const TranslatedText("Scan your first prescription or report to get started",
                      style: TextStyle(fontSize: 13, color: Color(0xFF5A6880)),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/doc-scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A3A3),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const TranslatedText("Scan Document"),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/qr-share'),
                      child: const TranslatedText("Or share from another app"),
                    ),
                  ],
                ),
              ),
            ),

          // Error State
          if (_showError)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Error illustration
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.error_outline, size: 52, color: Color(0xFFD63B3B)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const TranslatedText("Something went wrong",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFD63B3B)),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Retry button
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showError = false;
                          _errorMessage = '';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22A36A),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const TranslatedText("Try Again"),
                    ),
                  ],
                ),
              ),
            ),

          // Buttons to test edge cases
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _isOffline = !_isOffline),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A3A3)),
                  child: const TranslatedText("Toggle Offline Mode"),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _showError = !_showError;
                    _errorMessage = _showError ? "Failed to load records. Please check your connection." : '';
                  }),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD63B3B)),
                  child: const TranslatedText("Show Error State"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}