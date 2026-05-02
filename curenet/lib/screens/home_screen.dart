import 'dart:async';
import 'package:flutter/material.dart';
import '../services/consent_manager.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';
import '../core/data_mode.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../services/secure_storage_service.dart';

import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startGlobalPolling();
  }

  void _startGlobalPolling() {
    final cm = context.read<ConsentManager>();
    
    // 1. Regular poll to ensure state is fresh
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await cm.pollForRequests(Persona.abhaAddress);
    });

    // 2. Real-time stream listener for immediate notifications
    cm.requestStream.listen((request) {
      if (mounted) _showConsentPopUp(request);
    });
  }

  void _showConsentPopUp(ConsentArtefact request) {
    if (ModalRoute.of(context)?.settings.name == '/access-req') return;
    
    // Auto-navigate if the user is looking for it? No, show notification first.
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.security, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("LIVE ACCESS REQUEST", 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF00A3A3))),
                  Text("Doctor ${request.requester.name} is requesting access",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D2240),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: "REVIEW",
          textColor: const Color(0xFF00A3A3),
          onPressed: () => Navigator.pushNamed(context, '/access-req'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Request camera permission on startup so it's ready for scanning
    await Permission.camera.request();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cm = context.watch<ConsentManager>(); // Watch for request changes
    final user = auth.userProfile;
    final userName = user?['name'] ?? Persona.name;
    final abha = user?['abha'] ?? Persona.abhaNumber;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  
                  // Request Pop-up (If pending)
                  if (cm.pendingRequest != null)
                    _requestPopUpCard(cm.pendingRequest!),
                  
                  // ── BIOMETRIC SETUP PROMPT ──
              FutureBuilder<bool>(
                future: SecureStorageService.isBiometricsEnabled(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.data == false) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00A3A3), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint, color: Color(0xFF00A3A3)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: TranslatedText(
                              "Enable biometric login for faster access?",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D2240)),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await SecureStorageService.setBiometricsEnabled(true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Biometric login enabled!")),
                              );
                            },
                            child: const TranslatedText("Enable"),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // ── TOP HEADER ──
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
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A3A3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                Persona.name[0],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                              ),
                              Text(
                                abha,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
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

              // ── GREETING (long-press = hidden dev toggle) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const SizedBox(height: 8),
                    GestureDetector(
                      onLongPress: () => _showDevToggle(context),
                      child: TranslatedText(
                        "Good morning, ${userName.split(' ')[0]}",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── ABHAy AI BIG CARD ──
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
                              children: const [
                                TranslatedText(
                                  "Ask Abhya AI",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                TranslatedText(
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

              // ── QUICK ACTIONS GRID ──
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

              const SizedBox(height: 24),

              // ── CONSENT ACCESS LOG ──
              if (cm.artefacts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, size: 18, color: Color(0xFF0D2240)),
                          SizedBox(width: 6),
                          Text("Consent Access Log",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/access-ok'),
                        child: const Text("View all →",
                          style: TextStyle(fontSize: 13, color: Color(0xFF00A3A3), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ...cm.artefacts.reversed.take(3).map((artefact) {
                  final isActive = artefact.status == ConsentStatus.granted;
                  final isRevoked = artefact.status == ConsentStatus.revoked;

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
                  } else if (artefact.status == ConsentStatus.denied) {
                    statusColor = const Color(0xFF9BA8BB);
                    statusText = 'DENIED';
                    statusIcon = Icons.cancel;
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF22A36A).withOpacity(0.3)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.medical_services, size: 18, color: statusColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(artefact.requester.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? const Color(0xFF0D2240) : const Color(0xFF9BA8BB),
                                ),
                              ),
                              Text(
                                artefact.requestId,
                                style: const TextStyle(fontSize: 9, color: Color(0xFF9BA8BB), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          GestureDetector(
                            onTap: () {
                              cm.revokeConsent(artefact.consentId);
                              cm.sendResponse(Persona.abhaAddress, artefact.requestId, 'REVOKED');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Access revoked for ${artefact.requester.name}"),
                                  backgroundColor: const Color(0xFFD63B3B),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE8E8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.block, size: 12, color: Color(0xFFD63B3B)),
                                  SizedBox(width: 4),
                                  Text("Revoke",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD63B3B)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 10, color: statusColor),
                                const SizedBox(width: 3),
                                Text(statusText,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],

              // ── RECENT RECORDS HEADER ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TranslatedText("Recent Records", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240))),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/records'),
                      child: const TranslatedText("View all →", style: TextStyle(fontSize: 13, color: Color(0xFF00A3A3), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── SAMPLE RECORDS ──
              // ── SAMPLE RECORDS ──
              SizedBox(
                height: 110,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _recordCard(context, "Blood Test", "14 Mar 2026", Icons.science),
                    const SizedBox(width: 12),
                    _recordCard(context, "Prescription", "15 Feb 2026", Icons.medication),
                    const SizedBox(width: 12),
                    _recordCard(context, "Eye Checkup", "10 Jan 2026", Icons.visibility),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ],
  ),
  bottomNavigationBar: Container(
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
    );
  }

  // ── HIDDEN DEV TOGGLE (triple-tap on greeting) ──
  void _showDevToggle(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.developer_mode, color: Color(0xFFE07B39), size: 22),
              SizedBox(width: 8),
              Text("Dev Mode", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Switch between hardcoded demo data and real uploaded records.",
                style: TextStyle(fontSize: 13, color: Color(0xFF5A6880)),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: DataMode.isDemo,
                builder: (_, isDemo, __) => SwitchListTile(
                  title: Text(
                    isDemo ? "Demo Mode (Hardcoded)" : "Live Mode (Uploaded)",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isDemo ? "Using Priya Sharma persona" : "Using real scanned records",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
                  ),
                  value: isDemo,
                  activeColor: const Color(0xFFE07B39),
                  onChanged: (val) {
                    DataMode.toggle();
                    setDialogState(() {});
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPER WIDGETS ──
  Widget _requestPopUpCard(ConsentArtefact request) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2240),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00A3A3).withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFF00A3A3), shape: BoxShape.circle),
                child: const Icon(Icons.security, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("INCOMING ACCESS REQUEST", 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF00A3A3), letterSpacing: 0.5)),
                    Text(request.requester.name, 
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<ConsentManager>().denyConsent(request.consentId);
                    context.read<ConsentManager>().sendResponse(Persona.abhaAddress, request.requestId, 'DENIED');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("IGNORE", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/access-req'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A3A3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("REVIEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _recordCard(BuildContext context, String title, String date, IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/records'),
      child: Container(
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