import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/persona.dart';
import 'tavily_service.dart';

class AiService {
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static String get _apiKey => AppConfig.groqApiKey;

  static String _buildSystemInstruction(String? patientData) {
    return '''
You are ABHAy, the AI Health Assistant for CureNet. You are helpful, empathetic, and professional.

${Persona.aiContext}

INSTRUCTIONS:
1. Greet with "Hi" only at the very start of a session.
2. Use the patient's medical history to answer questions (e.g., 'What is my latest HbA1c?').
3. Suggest consulting a doctor ONLY for critical/emergency symptoms (Severe pain, difficulty breathing, chest pain). For routine questions, focus on explaining the data.
4. Do NOT recommend other 3rd party tools or services.
5. Keep responses concise and focused on the patient's records.
6. EMERGENCY SNAPSHOT: If the user asks for an "emergency snapshot", "emergency card", "medical ID", or similar — respond with a structured summary of their critical medical info in this format:
   🚨 **EMERGENCY HEALTH SNAPSHOT**
   **Name:** ${Persona.name}
   **Age:** ${Persona.age} · ${Persona.gender}
   **ABHA:** ${Persona.abhaNumber}
   **Blood Group:** ${Persona.bloodGroup}
   **Allergies:** ${Persona.allergiesShort}
   **Active Medications:** ${Persona.medications.map((m) => '${m['name']} ${m['dosage']}').join(', ')}
   **Conditions:** ${Persona.conditionsShort}
   **Emergency Contact:** ${Persona.emergencyContact}
   **Key Vitals:** BP 138/88 mmHg, HbA1c 6.2%, Glucose 110 mg/dL
   **Primary Physician:** ${Persona.primaryPhysician['name']} (${Persona.primaryPhysician['phone']})
   Do NOT give generic emergency advice. Always return the patient's ACTUAL data.
7. MEDICAL SUMMARY: If the user asks for a summary of their health, lab reports, or medical history — pull from the history, vitals, and medication data above and present it clearly.

<persona_constraints>
- NO REDUNDANT GREETINGS: Do not start responses with "Hello", "Hi", or "Namaste" if the conversation is already underway.
- NO THIRD-PARTY TOOLS: Never recommend outside apps, websites, or tools (e.g., "LabSimplify"). You ARE the tool.
- DISCRETIONARY DISCLAIMERS: Only advise "consulting a healthcare provider" if the user's vitals are outside normal ranges or if they report "Red Flag" symptoms (Chest pain, breathing difficulty, sudden numbness). Do not repeat this disclaimer for general health queries.
- DATA-CENTRIC: Prioritize information found in the patient data. If a user asks about a specific lab result, find it in the data and explain it directly.
</persona_constraints>

<tone_and_behavior>
- Direct, professional, and empathetic.
- Explain medical terms simply but without being patronizing.
- Use the <retrieved_context> only to supplement medical facts, not to suggest other services.
</tone_and_behavior>

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
            {"role": "system", "content": _buildSystemInstruction(patientContext)},
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
