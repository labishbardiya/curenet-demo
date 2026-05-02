import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';
import '../services/consent_manager.dart';

/// ─── Secure QR Share Screen (ABDM M3 Compliant) ──────────────────────────────
/// Generates a cryptographically signed QR code containing:
///   - ECDH X25519 public key for key agreement
///   - HMAC-SHA256 signed session token (tamper-proof)
///   - Time-bound expiry (30 minutes)
///   - Patient ABHA address for identity verification
///
/// The QR payload format:
///   curenet://consent?v=3&token=<base64url>&pub=<base64url X25519 pubkey>

class QrShareScreen extends StatefulWidget {
  const QrShareScreen({super.key});

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen>
    with SingleTickerProviderStateMixin {
  String? _qrData;
  bool _isGenerating = false;
  bool _qrActive = false;
  Timer? _expiryTimer;
  Timer? _pollingTimer;
  int _remainingSeconds = 0;
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
    _expiryTimer?.cancel();
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generateSecureQr() async {
    setState(() => _isGenerating = true);

    final consentManager = context.read<ConsentManager>();
    
    try {
      // Generate cryptographically secure QR data
      final qrData = await consentManager.generateSecureQrData(Persona.abhaAddress);

      setState(() {
        _qrData = qrData;
        _isGenerating = false;
        _qrActive = true;
        _remainingSeconds = 30 * 60; // 30 minutes
      });

      // Start countdown timer
      _expiryTimer?.cancel();
      _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { timer.cancel(); return; }
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            _revokeQr();
            timer.cancel();
          }
        });
      });

      // Start polling backend for doctor requests
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (!mounted || !_qrActive) { timer.cancel(); return; }
        
        final cm = context.read<ConsentManager>();
        await cm.pollForRequests(Persona.abhaAddress);
        
        if (cm.pendingRequest != null && mounted) {
          timer.cancel();
          Navigator.pushNamed(context, '/access-req');
        }
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR generation failed: $e'),
            backgroundColor: const Color(0xFFD63B3B),
          ),
        );
      }
    }
  }

  void _revokeQr() {
    final cm = context.read<ConsentManager>();
    
    // If there was an active request, notify doctor of revocation
    if (cm.pendingRequest != null) {
      cm.sendResponse(Persona.abhaAddress, cm.pendingRequest!.requestId, 'REVOKED');
    }

    cm.revokeQrSession();
    _expiryTimer?.cancel();
    _pollingTimer?.cancel();
    setState(() {
      _qrActive = false;
      _qrData = null;
      _remainingSeconds = 0;
    });
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // ── HEADER ─────────────────────────────────────────────────────
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
                // Security indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22A36A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, size: 14, color: Color(0xFF22A36A)),
                      SizedBox(width: 4),
                      Text("E2EE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF22A36A))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 24),
                  onPressed: () async {
                    final ok = await VoiceHelper.speak(
                      "Share with Doctor. Generate a secure QR code. The doctor scans it to request access. You approve in 1 tap. Data is encrypted end to end.",
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

          // ── BODY ───────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // ── SECURITY BANNER ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D2240), Color(0xFF1A3A5C)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user, size: 20, color: Color(0xFF00A3A3)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "ABDM M3 Compliant · ECDH X25519",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF00A3A3), letterSpacing: 0.5),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "AES-256-GCM encrypted · HMAC signed token",
                                style: TextStyle(fontSize: 9, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── QR CODE CARD ──
                  if (!_qrActive) ...[
                    // Pre-generation state
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: 0.4 + (_pulseController.value * 0.6),
                                child: const Icon(Icons.qr_code_2, size: 120, color: Color(0xFFD8DDE6)),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            Persona.abhaAddress,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: Color(0xFF0D2240),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ABHA: ${Persona.abhaNumber}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Generate button
                    ElevatedButton(
                      onPressed: _isGenerating ? null : _generateSecureQr,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A3A3),
                        minimumSize: const Size(double.infinity, 58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: const Color(0xFF00A3A3).withOpacity(0.5),
                      ),
                      child: _isGenerating
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 12),
                              Text("Generating ECDH keypair...", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code, color: Colors.white),
                              SizedBox(width: 10),
                              TranslatedText("Generate Secure Access QR",
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                    ),
                  ] else ...[
                    // Active QR state
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                        border: Border.all(
                          color: _remainingSeconds < 120
                            ? const Color(0xFFD32F2F).withOpacity(0.5)
                            : const Color(0xFF00A3A3).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Timer badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _remainingSeconds < 120
                                ? const Color(0xFFFDE8E8)
                                : const Color(0xFFE8F7F7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 14,
                                  color: _remainingSeconds < 120 ? const Color(0xFFD32F2F) : const Color(0xFF00A3A3),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Expires in ${_formatTime(_remainingSeconds)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _remainingSeconds < 120 ? const Color(0xFFD32F2F) : const Color(0xFF00A3A3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // The actual QR code (with encrypted payload)
                          QrImageView(
                            data: _qrData!,
                            version: QrVersions.auto,
                            size: 260, // Increased for better scan reliability
                            gapless: true,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black, // Pure black for max contrast
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                          ),

                          const SizedBox(height: 16),

                          // Session fingerprint (truncated for display)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fingerprint, size: 14, color: Color(0xFF9BA8BB)),
                                const SizedBox(width: 6),
                                Text(
                                  "Session: ${context.read<ConsentManager>().activeQrToken?.sessionId.substring(0, 8) ?? ''}...",
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9BA8BB), fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          Text(
                            Persona.abhaAddress,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFF0D2240)),
                          ),
                          const Text("ABDM Verified Patient", style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB))),
                          
                          const SizedBox(height: 20),
                          
                          // Copy link button (Backup)
                          OutlinedButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _qrData ?? ''));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Secure link copied to clipboard!")),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF00A3A3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, size: 14, color: Color(0xFF00A3A3)),
                                SizedBox(width: 8),
                                Text("Copy Secure Link", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Revoke button
                    ElevatedButton(
                      onPressed: _revokeQr,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          TranslatedText("Revoke QR & Terminate Session",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── HOW IT WORKS ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const TranslatedText("ABDM Consent Flow",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                        ),
                        const SizedBox(height: 10),
                        _stepRow("1", "Generate encrypted QR (ECDH + HMAC)"),
                        _stepRow("2", "Doctor scans → consent request via HIE-CM"),
                        _stepRow("3", "You review & approve in 1 tap"),
                        _stepRow("4", "Data encrypted with AES-256-GCM & sent"),
                        _stepRow("5", "Auto-expires in 30 min · Revoke anytime"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── EMERGENCY SNAPSHOT ──
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/emergency-snapshot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      minimumSize: const Size(double.infinity, 58),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency, color: Colors.white),
                        SizedBox(width: 10),
                        TranslatedText("Download Emergency Snapshot",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF00A3A3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF0D2240))),
          ),
        ],
      ),
    );
  }
}