import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';

class QrShareScreen extends StatelessWidget {
  const QrShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String abhaNumber = "91-2345-6789-0123"; // Dynamic in real app

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header (same as before)
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
                const Expanded(
                  child: TranslatedText("Share with Doctor",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 24),
                  onPressed: () async {
                    final ok = await VoiceHelper.speak(
                      "Share with Doctor. Your ABHA number is 91-2345-6789-0123. Show this QR to the doctor.",
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
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // REAL QR CODE
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: abhaNumber,
                          version: QrVersions.auto,
                          size: 220,
                          gapless: false,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D2240),
                        ),
                        const SizedBox(height: 20),
                        const TranslatedText("91-2345-6789-0123",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Color(0xFF0D2240),
                          ),
                        ),
                        const TranslatedText("@abdm",
                          style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions (same as v5)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        TranslatedText("How to use",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                        ),
                        const SizedBox(height: 8),
                        const TranslatedText(
                          "1. Show this QR to any doctor\n"
                          "2. They will scan & request access\n"
                          "3. You approve in 1 tap\n"
                          "4. Access expires in 30 minutes",
                          style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF0D2240)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/access-req'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2240),
                      minimumSize: const Size(double.infinity, 58),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const TranslatedText("Show QR to Doctor",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}