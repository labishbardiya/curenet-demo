import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String selectedLanguage = 'English'; // Default as per v5

  final List<Map<String, String>> languages = [
    {'name': 'English', 'native': ''},
    {'name': 'हिन्दी', 'native': 'Hindi'},
    {'name': 'বাংলা', 'native': 'Bengali'},
    {'name': 'తెలుగు', 'native': 'Telugu'},
    {'name': 'मराठी', 'native': 'Marathi'},
    {'name': 'தமிழ்', 'native': 'Tamil'},
    {'name': 'اردو', 'native': 'Urdu'},
    {'name': 'ગુજરાતી', 'native': 'Gujarati'},
    {'name': 'ಕನ್ನಡ', 'native': 'Kannada'},
    {'name': 'ଓଡ଼ିଆ', 'native': 'Odia'},
    {'name': 'മലയാളം', 'native': 'Malayalam'},
    {'name': 'ਪੰਜਾਬੀ', 'native': 'Punjabi'},
    {'name': 'অসমীয়া', 'native': 'Assamese'},
    {'name': 'मैथिली', 'native': 'Maithili'},
    {'name': 'संस्कृत', 'native': 'Sanskrit'},
    {'name': 'नेपाली', 'native': 'Nepali'},
    {'name': 'सिंधी', 'native': 'Sindhi'},
    {'name': 'कोंकणी', 'native': 'Konkani'},
    {'name': 'डोगरी', 'native': 'Dogri'},
    {'name': 'बड़ो', 'native': 'Bodo'},
    {'name': 'মৈতৈলোন্', 'native': 'Manipuri'},
    {'name': 'کٲشُر', 'native': 'Kashmiri'},
  ];

  void pickLanguage(String lang) {
    setState(() => selectedLanguage = lang);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header – exact v5
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
                  child: const Text(
                    '←',
                    style: TextStyle(fontSize: 26, color: Color(0xFF0D2240)),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D2240),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable language list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = lang['name'] == selectedLanguage;

                return GestureDetector(
                  onTap: () => pickLanguage(lang['name']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F7F7) : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFFD8DDE6),
                          width: index == languages.length - 1 ? 0 : 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Radio dot
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB),
                              width: isSelected ? 3 : 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0D2240),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          lang['name']!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D2240),
                          ),
                        ),
                        if (lang['native']!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            lang['native']!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9BA8BB),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Continue button – exact v5 teal
          Padding(
            padding: const EdgeInsets.all(18),
            child: ElevatedButton(
              onPressed: () {
                // In v5 it goes back to splash, but for real flow we go to Login Options
                Navigator.pushNamed(context, '/login-options');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A3A3),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}