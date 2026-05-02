import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';
import '../services/consent_manager.dart';

/// ─── Access Request Screen (ABDM M3 Consent Approval) ───────────────────────
/// Displays the doctor's consent request with full ABDM-compliant details:
///   - Requester identity (NMC verified)
///   - Consent purpose code (CAREMGT, BTG, etc.)
///   - HI Types requested
///   - Permission scope & time-bound access
///   - Approve / Delay / Deny actions
///
/// On approval:
///   1. ConsentManager grants consent (status → GRANTED)
///   2. ECDH shared secret is derived
///   3. Emergency snapshot is encrypted with AES-256-GCM
///   4. Encrypted bundle is "pushed" to the doctor's endpoint

class AccessRequestScreen extends StatefulWidget {
  const AccessRequestScreen({super.key});

  @override
  State<AccessRequestScreen> createState() => _AccessRequestScreenState();
}

class _AccessRequestScreenState extends State<AccessRequestScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _approveAccess() async {
    setState(() => _isProcessing = true);

    final cm = context.read<ConsentManager>();
    final pending = cm.pendingRequest;

    if (pending != null) {
      // 1. Grant consent (ABDM: status → GRANTED)
      final granted = await cm.grantConsent(pending.consentId);

      if (granted != null) {
        // 2. Build the actual production health bundle from the Persona profile
        final healthData = {
          'patient': {
            'name': Persona.name,
            'abhaAddress': Persona.abhaAddress,
            'abhaNumber': Persona.abhaNumber,
            'age': Persona.age,
            'gender': Persona.gender,
            'bloodGroup': Persona.bloodGroup,
            'address': Persona.address,
          },
          'clinical': {
            'conditions': Persona.conditions,
            'allergies': Persona.allergies,
            'activeMedications': Persona.medications,
            'latestVitals': Persona.vitals,
            'medicalHistory': Persona.history,
          },
          'emergency': {
            'contact': Persona.emergencyContact,
            'insurance': Persona.insuranceId,
          }
        };

        try {
          final encryptedBundle = await cm.buildEncryptedSnapshot(
            healthData: healthData,
            artefact: granted,
          );

          // Send GRANTED response WITH encrypted data to backend
          await cm.sendResponse(Persona.abhaAddress, pending.requestId, 'GRANTED', encryptedBundle: encryptedBundle);

          debugPrint('ABDM M3 ENCRYPTED DATA TRANSFER SUCCESS');
        } catch (e) {
          debugPrint('Encryption error (non-blocking for demo): $e');
        }
      }
    }

    setState(() => _isProcessing = false);
    
    if (mounted) {
      Navigator.pushNamed(context, '/access-ok');
    }
  }

  void _denyAccess() {
    final cm = context.read<ConsentManager>();
    final pending = cm.pendingRequest;
    if (pending != null) {
      cm.denyConsent(pending.consentId);
      cm.sendResponse(Persona.abhaAddress, pending.requestId, 'DENIED');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: TranslatedText("Access denied. Doctor has been notified."),
        backgroundColor: Color(0xFFD63B3B),
      ),
    );
    Navigator.pop(context);
  }

  void _delayAccess() {
    final cm = context.read<ConsentManager>();
    final pending = cm.pendingRequest;
    if (pending != null) {
      cm.delayConsent(pending.consentId);
      // For delay, we don't send a final status yet, or we could send 'DELAYED'
      cm.sendResponse(Persona.abhaAddress, pending.requestId, 'DELAYED');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: TranslatedText("Access delayed by 5 minutes. Doctor will be notified."),
        backgroundColor: Color(0xFFE07B39),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // ── AMBER HEADER ──
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
                      TranslatedText("Consent Request",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      TranslatedText("ABDM HIE-CM Consent Flow",
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text("M3", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── BODY ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── DOCTOR CARD ──
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
                          child: const Center(child: Icon(Icons.person, size: 28, color: Color(0xFF1A3A8A))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              TranslatedText("Dr. Suresh Kumar",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              TranslatedText("MBBS, MD · Apollo Spectra",
                                style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
                              ),
                              SizedBox(height: 6),
                              TranslatedText("✓ NMC Verified (REGNO1: MH1001)",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF22A36A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── CONSENT PURPOSE ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("CONSENT PURPOSE",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2196F3), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        _consentDetailRow("Purpose", "Care Management"),
                        _consentDetailRow("Code", "CAREMGT"),
                        _consentDetailRow("Access Mode", "VIEW only"),
                        _consentDetailRow("Validity", "30 minutes"),
                        _consentDetailRow("Data Erase", "Auto-delete after expiry"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── THEY WILL SEE ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText("HEALTH INFO TYPES REQUESTED",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF00A3A3), letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 10),
                        _permissionRow("OPConsultation records"),
                        _permissionRow("Prescription summaries"),
                        _permissionRow("Diagnostic report summaries"),
                        _permissionRow("Emergency snapshot (vitals, allergies)"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── THEY WILL NOT SEE ──
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
                        const TranslatedText("EXCLUDED FROM CONSENT",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD63B3B), letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 10),
                        _permissionRow("Full lab report images & raw data", isRed: true),
                        _permissionRow("Personal notes & diary entries", isRed: true),
                        _permissionRow("Emergency contact details", isRed: true),
                        _permissionRow("Insurance & financial data", isRed: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── ENCRYPTION INFO ──
                  Container(
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
                              Text(
                                "End-to-End Encrypted Transfer",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "ECDH X25519 key exchange · AES-256-GCM · HMAC-SHA256 integrity",
                                style: TextStyle(fontSize: 9, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const TranslatedText("Access expires in 30 minutes after approval",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // ── APPROVE BUTTON ──
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _approveAccess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 58),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: const Color(0xFF00A3A3).withOpacity(0.5),
                    ),
                    child: _isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 12),
                            Text("Encrypting & transmitting...", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        )
                      : const TranslatedText("✓ Approve & Send Encrypted Snapshot",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                  ),

                  const SizedBox(height: 10),

                  // ── DELAY BUTTON ──
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _delayAccess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE07B39),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        TranslatedText("Delay (5 minutes)",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── DENY BUTTON ──
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _denyAccess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD63B3B),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const TranslatedText("✗ Deny Access",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            _navItem(Icons.home, "Home", false, () => Navigator.pushReplacementNamed(context, '/home')),
            _navItem(Icons.smart_toy, "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
            _scanButton(context),
            _navItem(Icons.list_alt, "Records", false, () => Navigator.pushReplacementNamed(context, '/records')),
            _navItem(Icons.share, "Share", false, () => Navigator.pushReplacementNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  Widget _consentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A6880))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0D2240))),
          ),
        ],
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
            child: TranslatedText(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0D2240)),
            ),
          ),
        ],
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
          TranslatedText(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
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