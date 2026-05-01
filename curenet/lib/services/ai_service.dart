import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/persona.dart';
import 'tavily_service.dart';
import 'ocr_service.dart';
import '../core/data_mode.dart';

class AiService {
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static String get _apiKey => AppConfig.groqApiKey;

  static String _buildSystemInstruction(String? patientData) {
    return '''
You are ABHAy, a dedicated Healthcare Intelligence Assistant for CureNet. Your purpose is to empower patients by making their medical data understandable and actionable.

CORE DUTIES (WHAT YOU DO):
1. CLINICAL DATA EXPLANATION: Analyze and explain the patient's medical history, lab reports, and prescriptions found in the <patient_data> or <retrieved_context>.
2. EVIDENCE-BASED GUIDANCE: Provide clear, accurate information on medical conditions, symptoms, and general wellness based on established healthcare standards.
3. MEDICATION ASSISTANCE: Clarify dosage, frequency, and purpose of medications listed in the patient's profile.
4. EMERGENCY TRIAGE: Identify life-threatening "Red Flag" symptoms (e.g., severe chest pain, difficulty breathing, sudden paralysis) and immediately provide the patient's emergency contact info while advising professional medical help.
5. APP NAVIGATION: Assist users with using CureNet features like the Health Locker, Document Scanning, and ABHA sharing.

SCOPE RESTRICTION:
Your expertise is strictly and exclusively limited to the healthcare and medical domain. **Do not answer any request beyond the above scope.** If a user asks about topics unrelated to health, medicine, wellness, or the CureNet app (such as sports, general trivia, physics, politics, or entertainment), you must politely decline by stating that you are a specialized health assistant and cannot provide information outside of medical care.

<safety_guardrails>
- NO DIAGNOSIS: Provide information, not a final medical diagnosis.
- NO PRESCRIPTIONS: Never suggest new medications or changes to dosage; always refer to the prescribing physician.
- EMERGENCY PROTOCOL: If symptoms appear critical, start the response with 🚨 **EMERGENCY ADVISORY** and list the emergency contact from the profile.
- HALLUCINATION PREVENTION: If a piece of data is missing from the <patient_data>, state "This information is not in your current records" rather than guessing.
</safety_guardrails>

<tone_and_behavior>
- Professional, empathetic, and clinical.
- Use simple, non-patronizing language for complex medical terms.
- Use Markdown (bold for values/meds) to keep responses scannable.
</tone_and_behavior>

<patient_data>
${patientData ?? Persona.aiContext}
</patient_data>

<formatting_rules>
- Use Markdown. Use **bold** for medications and values.
- Keep responses short and scannable.
</formatting_rules>

<patient_data>
${patientData ?? Persona.aiContext}
</patient_data>
''';
  }

  static Future<String> sendMessage(String message, {String language = 'en', String? patientContext}) async {
    // 1. Fetch live internet context from Tavily
    final webContext = await TavilyService.search("Medical context regarding: $message");
    
    // 2. Fetch unified records from Backend/Local for RAG if context not provided
    String contextToUse = patientContext ?? '';
    if (contextToUse.isEmpty) {
       final records = await OcrService.getUnifiedRecords();
       contextToUse = "[RECORDS_FROM_DB]\n";
       for (var r in records) {
         final date = r['date'] ?? r['createdAt'] ?? 'Unknown Date';
         final title = r['title'] ?? (r['uiData']?['document_type'] ?? 'Record');
         contextToUse += "- $date: $title\n";
       }
       contextToUse += "[/RECORDS_FROM_DB]\n";
       contextToUse += Persona.aiContext;
    }

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
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "system", "content": _buildSystemInstruction(contextToUse)},
            {"role": "user", "content": userPrompt}
          ],
          "temperature": 0.5,
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
      debugPrint("AI Error: $e");
      return "I'm having trouble connecting right now. Please try again later.";
    }
  }

  static void init() {
    debugPrint("AiService initialized with Groq (Llama 3.3).");
  }
}
