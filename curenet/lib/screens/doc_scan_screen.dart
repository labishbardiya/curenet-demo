import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import 'scan_result_screen.dart';
import '../core/app_config.dart';

class DocScanScreen extends StatefulWidget {
  const DocScanScreen({super.key});

  @override
  State<DocScanScreen> createState() => _DocScanScreenState();
}

class _DocScanScreenState extends State<DocScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  XFile? _pickedFile; // Use XFile for cross-platform (web + mobile) support
  final ImagePicker _picker = ImagePicker();
  
  bool _isUploading = false;
  bool _isProcessing = false;
  String _statusText = "Scan prescriptions, reports & documents";

  // On Android Emulator: 10.0.2.2 maps to host localhost
  // On Web/Windows: use localhost directly
  // On Android Emulator: 10.0.2.2 maps to host localhost
  // On Web/Windows: use localhost directly
  String get _ocrApiUrl => AppConfig.ocrApiUrl;


  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.15, end: 0.80).animate(_scanController);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600, // Sufficient for high-quality OCR
        maxHeight: 1600,
        imageQuality: 85, // Significant file size reduction with minimal quality loss
      );

      if (photo != null) {
        setState(() {
          _pickedFile = photo;
        });
        _uploadXFile(photo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open media: $e')),
      );
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const TranslatedText("Choose Document Source", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFF00A3A3)),
                  title: const TranslatedText('Gallery / Upload Doc'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  }),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF00A3A3)),
                title: const TranslatedText('Take Health Photo'),
                onTap: () {
                   Navigator.of(context).pop();
                   _handleCameraScan();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Future<void> _handleCameraScan() async {
    // Check if permission was already granted (Ask only once)
    var status = await Permission.camera.status;
    
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      _pickImage(ImageSource.camera);
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is disabled. Please enable it in Settings.')),
        );
      }
    }
  }

  Future<void> _uploadXFile(XFile file) async {
    print('DEBUG: Initiating upload to $_ocrApiUrl');
    setState(() {
      _isUploading = true;
      _statusText = "Uploading Document to ABDM OCR...";
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_ocrApiUrl/scan'));
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 202) {
        var jsonResponse = jsonDecode(response.body);
        String jobId = jsonResponse['data']['jobId'];
        
        setState(() {
          _isUploading = false;
          _isProcessing = true;
          _statusText = "Processing OCR Payload. Please wait...";
        });

        _pollOCRStatus(jobId);
      } else {
        throw Exception('Server rejected upload (${response.statusCode}).');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusText = "Upload Failed! Try again.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _pollOCRStatus(String jobId) {
    Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      try {
        final response = await http.get(Uri.parse('$_ocrApiUrl/status/$jobId'));
        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          
          if (jsonData['data']['state'] == 'processing' || jsonData['data']['state'] == 'pending') {
            // Still processing
            return; 
          }

          if (jsonData['data']['status'] == 'completed') {
            timer.cancel();
            setState(() {
              _isProcessing = false;
              _statusText = "ABDM FHIR Bundle Ready!";
            });
            
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ScanResultScreen(
                    uiData: jsonData['data']['ui_data'] ?? {},
                    fhirBundle: jsonData['data']['fhir_bundle'] ?? jsonData['data']['fhirBundle'] ?? {},
                    abdmContext: jsonData['data']['abdmContext'] ?? {},
                    imagePath: _pickedFile?.path,
                  ),
                ),
              );
            }
          } else {
            // Failed
            timer.cancel();
            String errorMsg = jsonData['data']['error'] ?? "Job Failed. Try again.";
            setState(() {
              _isProcessing = false;
              _statusText = errorMsg;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      } catch (e) {
        // Ignore single poll failures temporarily
      }
    });
  }

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText("Scan & Upload",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      TranslatedText(_statusText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF00C4C4)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 12),

                  // Camera Viewfinder or Image Preview
                  Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF050F1A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF00A3A3), width: 3),
                    ),
                    child: _pickedFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            // Image.network works on web via object URL; Image.file for native
                            child: kIsWeb
                                ? Image.network(_pickedFile!.path, fit: BoxFit.cover)
                                : Image.file(File(_pickedFile!.path), fit: BoxFit.cover),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(top: 12, left: 12, child: _cornerBracket()),
                              Positioned(top: 12, right: 12, child: _cornerBracket(rotate: true)),
                              Positioned(bottom: 12, left: 12, child: _cornerBracket(rotate: true, bottom: true)),
                              Positioned(bottom: 12, right: 12, child: _cornerBracket(bottom: true)),

                              AnimatedBuilder(
                                animation: _scanAnimation,
                                builder: (context, child) {
                                  return Positioned(
                                    top: _scanAnimation.value * 220 + 20,
                                    left: 20,
                                    right: 20,
                                    child: Container(
                                      height: 2,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.transparent, Color(0xFF00A3A3), Colors.transparent],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_enhance, size: 48, color: Colors.white54),
                                  SizedBox(height: 8),
                                  TranslatedText("Camera Ready",
                                    style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 20),

                  if (_isUploading || _isProcessing)
                    Column(
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF00A3A3)),
                        const SizedBox(height: 16),
                        TranslatedText(
                           _isUploading ? "Uploading..." : "Processing OCR into FHIR Bundle...",
                           style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2240)),
                        )
                      ],
                    )
                  else ...[
                    // Instruction card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00A3A3).withOpacity(0.15)),
                      ),
                      child: const Column(
                        children: [
                          TranslatedText("Point camera at document",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                          ),
                          SizedBox(height: 8),
                          TranslatedText("Align your prescription, lab report, or QR code within the frame. The document will be mapped to FHIR and saved.",
                            style: TextStyle(fontSize: 13, color: Color(0xFF5A6880), height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // What you can scan
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: TranslatedText("WHAT YOU CAN SCAN",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB), letterSpacing: 0.4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _scanItem(Icons.medication, "Prescriptions & Medicines"),
                    _scanItem(Icons.science, "Lab Reports & Blood Tests"),
                    _scanItem(Icons.medical_services, "X-Ray & Radiology Reports"),
                    _scanItem(Icons.qr_code_scanner, "Doctor's ABHA QR Code"),

                    const SizedBox(height: 32),

                    ElevatedButton.icon(
                      onPressed: _showPickerOptions,
                      icon: const Icon(Icons.add_a_photo, color: Colors.white),
                      label: const TranslatedText("Select Document",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A3A3),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ]
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

  Widget _scanItem(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF0D2240)),
          const SizedBox(width: 12),
          TranslatedText(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cornerBracket({bool rotate = false, bool bottom = false}) {
    return Transform.rotate(
      angle: rotate ? (bottom ? 1.57 : -1.57) : 0,
      child: const Icon(Icons.square_outlined, size: 28, color: Color(0xFF00A3A3)),
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
      onTap: () {}, // Already on this screen
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
                  Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  SizedBox(height: 2),
                  TranslatedText("SCAN", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}