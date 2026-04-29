import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'tavily_service.dart';
import '../core/app_config.dart';

class AiService {
  static String get _apiKey => AppConfig.groqApiKey;
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  static final String _patientContext = '''
[PATIENT_DATA]
Name: Priya Sharma
Age: 45
Gender: Female
ABHA Address: priya45@abdm
Known Conditions: Hypertension (Stage 1)
Current Medications:
- Amlodipine 5mg (1x daily, morning) - Prescribed: 22 Feb 2026
Recent Vitals:
- Blood Pressure: 142/90 mmHg (Date: 15 Mar 2026)
Upcoming Appointments:
- Cardiology Follow-up: Dr. Meena Kapoor, 22 March 2026
[/PATIENT_DATA]
''';

  static final String _systemInstruction = '''
<system_role>
You are Abhya, a highly secure, empathetic, and culturally aware AI health assistant integrated into the CureNet platform. 
Your primary function is to help the user understand their medical records, clarify medical terminology, and track their health journey. 
You are an AI, NOT a licensed human medical doctor. You must never definitively diagnose, prescribe, or give definitive medical advice. Always defer critical decisions to the user's healthcare provider.
</system_role>

<tone_and_behavior>
- EMPATHETIC & REASSURING: Always respond warmly. Be encouraging but grounded.
- ACCESSIBLE: Never use complex medical jargon without immediately explaining it in simple terms.
- SAFETY FIRST: If a user reports severe symptoms (e.g., chest pain, severe bleeding, difficulty breathing), immediately advise them to seek emergency medical care.
- HALLUCINATION PREVENTION: Answer ONLY using the information provided in <patient_data> and <retrieved_context>. If the information is not present, explicitly state: "I don't have that information in your records." Do not make up facts.
</tone_and_behavior>

<formatting_rules>
- Use Markdown for readability.
- Use bullet points for lists.
- Bold important entities like **medications**, **dates**, and **vitals**.
- AVOID using hashtags (#) and asterisks (*) except for bolding. DO NOT use excessive formatting, as it negatively impacts Text-to-Speech engines.
</formatting_rules>

<patient_data>
$_patientContext
</patient_data>
''';

  static void init() {
    debugPrint('AiService initialized with Groq (Llama 3).');
  }

  static Future<String> sendMessage(String message, {String language = 'en'}) async {
    // 1. Fetch live internet context from Tavily
    final webContext = await TavilyService.search("Medical context regarding: $message");
    
    try {
      final String langName = language == 'hi' ? 'Hindi' : (language == 'bn' ? 'Bengali' : 'English');
      
      String userPrompt = "CRITICAL INSTRUCTION: You MUST reply entirely in $langName. Do not use English unless citing a specific medical term. \n\n";
      if (webContext != null) {
        userPrompt += "[WEB_SEARCH_CONTEXT]\n$webContext\n[/WEB_SEARCH_CONTEXT]\n\n";
      }
      userPrompt += "User message: $message";

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile", // Using Llama 3.3 70B for high quality responses
          "messages": [
            {"role": "system", "content": _systemInstruction},
            {"role": "user", "content": userPrompt}
          ],
          "temperature": 0.5, // Lower temperature for more factual, grounded responses
          "max_tokens": 1024,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? "I couldn't process that.";
      } else {
        debugPrint("Groq Error: ${response.statusCode} - ${response.body}");
        return "I'm having trouble processing that right now.";
      }
    } catch (e) {
      debugPrint("AI Error: \$e");
      return "I'm having trouble connecting right now. Please try again later.";
    }
  }
}
