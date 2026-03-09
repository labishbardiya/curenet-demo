import 'package:flutter/material.dart';
import 'dart:async';
import '../core/theme.dart';
import '../core/translated_text.dart';
import 'package:curenet/core/navigation_helper.dart';

class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({super.key});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String _otp = '';
  int _timerSeconds = 30;
  Timer? _timer;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    setState(() {
      _otp = _controllers.map((c) => c.text).join();
      _showError = false;
    });

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  void _verifyOtp() {
    if (_otp == '123456') {
      _timer?.cancel();
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      setState(() => _showError = true);
      // Clear on error
      Future.delayed(const Duration(milliseconds: 800), () {
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
        setState(() => _showError = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                ),
                const SizedBox(width: 14),
                const TranslatedText(
                  "Enter OTP",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Illustration
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text("📨", style: TextStyle(fontSize: 48)),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const TranslatedText(
                    "6-digit OTP sent to",
                    style: TextStyle(fontSize: 13, color: Color(0xFF5A6880)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "+91 98765 43210",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),

                  const SizedBox(height: 32),

                  // OTP Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 46,
                        height: 54,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _controllers[index].text.isNotEmpty
                                ? const Color(0xFF00A3A3)
                                : const Color(0xFFD8DDE6),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          onChanged: (val) => _onOtpChanged(index, val),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 12),

                  // Timer & Resend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const TranslatedText("Resend in: ", style: TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
                      Text(
                        "${_timerSeconds}s",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF22A36A)),
                      ),
                      const SizedBox(width: 20),
                      if (_timerSeconds == 0)
                        GestureDetector(
                          onTap: () {
                            _startTimer();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("OTP resent ✓"), backgroundColor: Color(0xFF00A3A3)),
                            );
                          },
                          child: const TranslatedText(
                            "Resend OTP",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Error message
                  if (_showError)
                    const TranslatedText(
                      "❌ Incorrect OTP. Please try again.",
                      style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                    ),

                  const SizedBox(height: 32),

                  // Verify Button
                  ElevatedButton(
                    onPressed: _otp.length == 6 ? _verifyOtp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const TranslatedText(
                      "Verify OTP →",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const TranslatedText(
                    "Demo OTP: 123456",
                    style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
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