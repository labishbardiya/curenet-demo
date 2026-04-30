import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:typed_data';
import '../core/persona.dart';
import '../core/translated_text.dart';

class EmergencySnapshotScreen extends StatefulWidget {
  const EmergencySnapshotScreen({super.key});

  @override
  State<EmergencySnapshotScreen> createState() => _EmergencySnapshotScreenState();
}

class _EmergencySnapshotScreenState extends State<EmergencySnapshotScreen>
    with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _captureAndSave() async {
    final Uint8List? image = await _screenshotController.capture();
    if (image != null) {
      await ImageGallerySaverPlus.saveImage(image, name: "CureNet_Emergency_Snapshot");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText("✅ Snapshot saved to gallery!"),
            backgroundColor: Color(0xFF22A36A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2240),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          "Emergency Card",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _captureAndSave,
            tooltip: "Save to Gallery",
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Screenshot(
            controller: _screenshotController,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── RED EMERGENCY BANNER ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "EMERGENCY HEALTH CARD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // ── PATIENT IDENTITY ROW ──
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00A3A3), Color(0xFF1A3A5C)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  Persona.name[0],
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Name & ABHA
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Persona.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0D2240),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${Persona.age} yrs · ${Persona.gender}",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF5A6880),
                                    ),
                                  ),
                                  Text(
                                    "ABHA: ${Persona.abhaNumber}",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9BA8BB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Blood Group Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE8E8),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.bloodtype, size: 18, color: Color(0xFFD32F2F)),
                                  const SizedBox(height: 2),
                                  Text(
                                    Persona.bloodGroup,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(height: 1, color: Color(0xFFE8ECF0)),
                        const SizedBox(height: 16),

                        // ── ALLERGIES (RED HIGHLIGHT) ──
                        _criticalSection(
                          icon: Icons.warning_amber_rounded,
                          label: "ALLERGIES",
                          value: Persona.allergiesShort,
                          bgColor: const Color(0xFFFDE8E8),
                          iconColor: const Color(0xFFD32F2F),
                          textColor: const Color(0xFFD32F2F),
                        ),

                        const SizedBox(height: 12),

                        // ── ACTIVE MEDICATIONS ──
                        _criticalSection(
                          icon: Icons.medication_rounded,
                          label: "ACTIVE MEDICATIONS",
                          value: Persona.medications
                              .map((m) => "${m['name']} ${m['dosage']} (${m['frequency']})")
                              .join('\n'),
                          bgColor: const Color(0xFFFFF3E6),
                          iconColor: const Color(0xFFE07B39),
                          textColor: const Color(0xFFB35A1F),
                        ),

                        const SizedBox(height: 12),

                        // ── CONDITIONS ──
                        _criticalSection(
                          icon: Icons.monitor_heart_rounded,
                          label: "CONDITIONS",
                          value: Persona.conditionsShort,
                          bgColor: const Color(0xFFE8F4FD),
                          iconColor: const Color(0xFF2196F3),
                          textColor: const Color(0xFF1565C0),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE8ECF0)),
                        const SizedBox(height: 14),

                        // ── TWO-COLUMN: VITALS + PHYSICIAN ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Latest Vitals
                            Expanded(
                              child: _infoBlock(
                                icon: Icons.favorite_rounded,
                                iconColor: const Color(0xFFD32F2F),
                                label: "KEY VITALS",
                                lines: [
                                  "BP: 138/88 mmHg",
                                  "HbA1c: 6.2%",
                                  "Glucose: 110 mg/dL",
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Primary Physician
                            Expanded(
                              child: _infoBlock(
                                icon: Icons.medical_information_rounded,
                                iconColor: const Color(0xFF00A3A3),
                                label: "PHYSICIAN",
                                lines: [
                                  Persona.primaryPhysician['name']!,
                                  Persona.primaryPhysician['specialty']!,
                                  Persona.primaryPhysician['phone']!,
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE8ECF0)),
                        const SizedBox(height: 14),

                        // ── EMERGENCY CONTACT ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7EF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF22A36A).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22A36A).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(Icons.call, size: 20, color: Color(0xFF22A36A)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "EMERGENCY CONTACT",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF22A36A),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Persona.emergencyRelation,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0D2240),
                                      ),
                                    ),
                                    Text(
                                      Persona.emergencyPhone,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF22A36A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── FOOTER ──
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user, size: 14, color: Color(0xFF00A3A3)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "CureNet Verified · ABDM Linked · DPDP Compliant",
                                  style: TextStyle(fontSize: 9, color: Color(0xFF9BA8BB), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── CRITICAL SECTION (Allergies / Meds / Conditions) ──
  Widget _criticalSection({
    required IconData icon,
    required String label,
    required String value,
    required Color bgColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Icon(icon, size: 18, color: iconColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── INFO BLOCK (Vitals / Physician) ──
  Widget _infoBlock({
    required IconData icon,
    required Color iconColor,
    required String label,
    required List<String> lines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: iconColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...lines.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              l,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D2240),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
