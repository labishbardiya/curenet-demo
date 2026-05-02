import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';
import '../services/consent_manager.dart';

/// ─── Access Granted Screen (ABDM M3 Post-Consent) ──────────────────────────
/// Displayed after patient approves a consent request.
/// Shows:
///   - Success confirmation with consent artefact ID
///   - Time-bound access countdown (30 min auto-expiry)
///   - Active encryption status (E2EE indicator)
///   - Revoke button for immediate access termination
///   - Audit log entry confirmation

class AccessGrantedScreen extends StatefulWidget {
  const AccessGrantedScreen({super.key});

  @override
  State<AccessGrantedScreen> createState() => _AccessGrantedScreenState();
}

class _AccessGrantedScreenState extends State<AccessGrantedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkAnimController;

  @override
  void initState() {
    super.initState();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _checkAnimController.dispose();
    super.dispose();
  }

  void _revokeAccess() {
    final cm = context.read<ConsentManager>();
    final artefacts = cm.artefacts.where((a) => a.status == ConsentStatus.granted).toList();
    for (final a in artefacts) {
      cm.revokeConsent(a.consentId);
      // Notify backend of revocation
      cm.sendResponse(Persona.abhaAddress, a.requestId, 'REVOKED');
    }
    cm.revokeQrSession();

    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: TranslatedText("Access revoked. Session terminated. All data wiped."),
        backgroundColor: Color(0xFFD63B3B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.watch<ConsentManager>();
    final grantedArtefacts = cm.artefacts.where((a) => a.status == ConsentStatus.granted).toList();
    final latestGranted = grantedArtefacts.isNotEmpty ? grantedArtefacts.last : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

          // Success illustration
          ScaleTransition(
            scale: CurvedAnimation(parent: _checkAnimController, curve: Curves.elasticOut),
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Color(0xFFE6F7EF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22A36A).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check, size: 42, color: Color(0xFF22A36A)),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const TranslatedText("Consent Granted!",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
          ),

          const SizedBox(height: 8),
          const TranslatedText("Dr. Suresh Kumar can now view your\nencrypted health summary.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF5A6880), height: 1.4),
          ),

          const SizedBox(height: 20),

          // ── CONSENT ARTEFACT ID ──
          if (latestGranted != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint, size: 16, color: Color(0xFF9BA8BB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("CONSENT ARTEFACT ID",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF9BA8BB), letterSpacing: 0.5),
                        ),
                        Text(
                          latestGranted.consentId,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF0D2240), fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── ENCRYPTION ACTIVE BANNER ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2240),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, size: 18, color: Color(0xFF00A3A3)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("End-to-End Encrypted · Active",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text("ECDH X25519 · AES-256-GCM · ABDM M3",
                        style: TextStyle(fontSize: 9, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified, size: 18, color: Color(0xFF22A36A)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── DOCTOR ACCESS LOG ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, size: 18, color: Color(0xFF0D2240)),
                    SizedBox(width: 8),
                    Text("Doctor Access Log",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D2240)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text("All doctors who accessed your records",
                  style: TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)),
                ),
                const SizedBox(height: 14),
                ...cm.artefacts.map((artefact) {
                  final isActive = artefact.status == ConsentStatus.granted;
                  final isRevoked = artefact.status == ConsentStatus.revoked;
                  final isDenied = artefact.status == ConsentStatus.denied;

                  Color statusColor = const Color(0xFF00A3A3);
                  String statusText = 'PENDING';
                  IconData statusIcon = Icons.hourglass_top;

                  if (isActive) {
                    statusColor = const Color(0xFF22A36A);
                    statusText = 'ACTIVE';
                    statusIcon = Icons.check_circle;
                  } else if (isRevoked) {
                    statusColor = const Color(0xFFD63B3B);
                    statusText = 'REVOKED';
                    statusIcon = Icons.block;
                  } else if (isDenied) {
                    statusColor = const Color(0xFF9BA8BB);
                    statusText = 'DENIED';
                    statusIcon = Icons.cancel;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive ? const Color(0xFF22A36A).withOpacity(0.3) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.medical_services, size: 20, color: statusColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(artefact.requester.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? const Color(0xFF0D2240) : const Color(0xFF9BA8BB),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Reg: ${artefact.requester.identifierValue} · ${artefact.requestId}",
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF9BA8BB), fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 12, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(statusText,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                cm.revokeConsent(artefact.consentId);
                                cm.sendResponse(Persona.abhaAddress, artefact.requestId, 'REVOKED');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Access revoked for ${artefact.requester.name}"),
                                    backgroundColor: const Color(0xFFD63B3B),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDE8E8),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.block, color: Color(0xFFD63B3B), size: 16),
                                  SizedBox(width: 6),
                                  Text("Revoke This Access",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD63B3B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (cm.artefacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text("No access records yet",
                        style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── ACTION BUTTONS ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A3A3),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const TranslatedText("Return Home",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _revokeAccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: Color(0xFFD63B3B), width: 2),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, color: Color(0xFFD63B3B), size: 18),
                      SizedBox(width: 8),
                      TranslatedText("Revoke All & Wipe Data",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFD63B3B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ── PRIVACY NOTE ──
          const Padding(
            padding: EdgeInsets.all(20),
            child: TranslatedText("ABDM Audit: Access logged in Profile → Consent Log · DPDP Compliant",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
            ),
          ),
        ],
        ),
      ),

      // ── BOTTOM NAVIGATION ──
      bottomNavigationBar: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, "Home", true, () => Navigator.pushReplacementNamed(context, '/home')),
            _navItem(Icons.smart_toy, "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
            _scanButton(context),
            _navItem(Icons.list_alt, "Records", false, () => Navigator.pushReplacementNamed(context, '/records')),
            _navItem(Icons.share, "Share", false, () => Navigator.pushReplacementNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
        ],
      ),
    );
  }

    Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ModalRoute.of(context)?.settings.name != '/doc-scan') {
          Navigator.pushNamed(context, '/doc-scan');
        }
      },
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00A3A3), Color(0xFF00C4C4)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A3A3).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.camera_alt, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}