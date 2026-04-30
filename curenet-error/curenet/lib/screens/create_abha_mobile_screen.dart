import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';

class CreateAbhaMobileScreen extends StatefulWidget {
  const CreateAbhaMobileScreen({super.key});

  @override
  State<CreateAbhaMobileScreen> createState() => _CreateAbhaMobileScreenState();
}

class _CreateAbhaMobileScreenState extends State<CreateAbhaMobileScreen> {
  final TextEditingController _mobileController = TextEditingController();
  bool _termsAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 44, 18, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFD8DDE6))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('←', style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                  ),
                  const Spacer(),
                  const TranslatedText('Create ABHA',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText('Mobile Number',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                    ),
                    const SizedBox(height: 12),
                    const TranslatedText('Enter your mobile number to create ABHA',
                      style: TextStyle(fontSize: 15, color: Color(0xFF9BA8BB)),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter mobile number',
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(color: Color(0xFF0D2240)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00A3A3)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _termsAgreed = !_termsAgreed),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD8DDE6)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _termsAgreed
                                ? const Center(
                              child: Text('✓', style: TextStyle(fontSize: 16, color: Color(0xFF00A3A3))),
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
                                ),
                                TextSpan(
                                  text: 'Terms & Conditions ',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                                ),
                                TextSpan(
                                  text: 'and ',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
                                ),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                                ),
                                TextSpan(
                                  text: '.',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: ElevatedButton(
                onPressed: _mobileController.text.length == 10 && _termsAgreed
                    ? () => Navigator.pushNamed(context, '/mobile-otp-verify')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mobileController.text.length == 10 && _termsAgreed
                      ? const Color(0xFF00A3A3)
                      : const Color(0xFFD8DDE6),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: TranslatedText('Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _mobileController.text.length == 10 && _termsAgreed
                        ? Colors.white
                        : const Color(0xFF9BA8BB),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }
}