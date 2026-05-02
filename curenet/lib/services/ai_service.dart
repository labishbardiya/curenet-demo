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
You are ABHAy, a Healthcare Intelligence Assistant for CureNet.

RULES:
1. ONLY use facts from <patient_data>. NEVER invent, assume, or speculate beyond what is provided.
2. If information is not in <patient_data>, say: "This information is not in your current records."
3. Keep responses concise: 3-5 sentences max for simple questions. Use bullet points for lists.
4. Use **bold** for medication names, values, and dates.
5. NEVER suggest new medications or diagnose. Always recommend consulting the listed physician.
6. For emergencies (chest pain, breathing difficulty, sudden paralysis), start with 🚨 **EMERGENCY** and provide the emergency contact.
7. Only answer health/medical/CureNet questions. Politely decline anything else.
8. Be warm and professional. Use simple language.

<patient_data>
${patientData ?? (DataMode.activeUserId == DataMode.arjunId ? Persona.aiContext : 'No patient records uploaded yet. Ask the user to upload prescriptions or lab reports.')}
</patient_data>
''';
  }

  static Future<String> sendMessage(String message, {String language = 'en', String? patientContext}) async {
    final stream = sendMessageStream(message, language: language, patientContext: patientContext);
    String fullResponse = "";
    await for (final chunk in stream) {
      fullResponse += chunk;
    }
    return fullResponse.isNotEmpty ? fullResponse : "I'm having trouble processing that right now.";
  }

  static Future<String> _identifyIntent(String message) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {
              "role": "system", 
              "content": "Classify the user message into: [MEDICAL_QUERY, GENERAL_CHAT, APP_HELP]. Return ONLY the label."
            },
            {"role": "user", "content": message}
          ],
          "temperature": 0.0,
          "max_tokens": 10,
        }),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content']?.trim() ?? "MEDICAL_QUERY";
      }
      return "MEDICAL_QUERY";
    } catch (_) {
      return "MEDICAL_QUERY";
    }
  }

  static Stream<String> sendMessageStream(String message, {String language = 'en', String? patientContext}) async* {
    try {
      // ═══ PARALLEL PIPELINE: Run all lookups simultaneously ═══
      // This cuts latency from ~12s to ~4s by not waiting sequentially.
      
      final intentFuture = _identifyIntent(message);
      final webFuture = TavilyService.search("Medical context: $message")
          .timeout(const Duration(seconds: 4))
          .catchError((_) => null);
      final atomsFuture = (patientContext == null)
          ? OcrService.getClinicalAtoms()
              .timeout(const Duration(seconds: 3))
              .catchError((_) => <Map<String, dynamic>>[])
          : Future.value(<Map<String, dynamic>>[]);
      final semanticFuture = (patientContext == null)
          ? OcrService.searchSemantic(message)
              .timeout(const Duration(seconds: 3))
              .catchError((_) => <Map<String, dynamic>>[])
          : Future.value(<Map<String, dynamic>>[]);

      // Wait for all in parallel
      final results = await Future.wait([intentFuture, webFuture, atomsFuture, semanticFuture]);

      final String intent = results[0] as String;
      final String? webResult = results[1] as String?;
      final List<Map<String, dynamic>> atoms = results[2] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> semanticResults = results[3] as List<Map<String, dynamic>>;

      debugPrint("AI Routing: Intent=$intent | Web=${webResult != null ? 'Yes' : 'No'} | Atoms=${atoms.length} | Semantic=${semanticResults.length}");

      String webContext = (intent == "MEDICAL_QUERY") ? (webResult ?? "") : "";
      String clinicalAtomsContext = "";

      if (intent == "MEDICAL_QUERY" && patientContext == null) {
        // Build atoms context
        if (atoms.isNotEmpty) {
          clinicalAtomsContext = "[RECENT_CLINICAL_FACTS]\n";
          final recentAtoms = atoms.length > 20 ? atoms.sublist(atoms.length - 20) : atoms;
          for (var a in recentAtoms) {
            final type = a['type'] ?? 'Record';
            final name = a['name'] ?? 'Unknown';
            final val = a['value'] ?? '';
            final unit = a['unit'] ?? '';
            final date = a['date'] ?? 'Unknown';
            clinicalAtomsContext += "- [$date] $type: $name $val $unit\n";
          }
          clinicalAtomsContext += "[/RECENT_CLINICAL_FACTS]\n";
        }

        // Build semantic context
        if (semanticResults.isNotEmpty) {
          clinicalAtomsContext += "\n[RELEVANT_HISTORICAL_CONTEXT]\n";
          for (var r in semanticResults) {
            final abdm = r['abdmContext'] ?? {};
            final display = abdm['displayString'] ?? abdm['documentType'] ?? 'Record';
            clinicalAtomsContext += "- Reference: $display\n";
          }
          clinicalAtomsContext += "[/RELEVANT_HISTORICAL_CONTEXT]\n";
        }
      }

      // Only inject Persona context for demo identity (Arjun Mishra)
      // Live user gets AI context purely from uploaded documents
      final String personaContext = DataMode.activeUserId == DataMode.arjunId 
          ? Persona.aiContext 
          : '';
      final String contextToUse = (patientContext ?? clinicalAtomsContext) + personaContext;

      final String langName = language == 'hi' ? 'Hindi' : (language == 'bn' ? 'Bengali' : 'English');
      
      String userPrompt = "CRITICAL INSTRUCTION: You MUST reply entirely in $langName. \n\n";
      if (webContext.isNotEmpty) {
        userPrompt += "[WEB_SEARCH_CONTEXT]\n$webContext\n[/WEB_SEARCH_CONTEXT]\n\n";
      }
      userPrompt += "User message: $message";

      final request = http.Request('POST', Uri.parse(_apiUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });
      request.body = jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": [
          {"role": "system", "content": _buildSystemInstruction(contextToUse)},
          {"role": "user", "content": userPrompt}
        ],
        "temperature": 0.5,
        "max_tokens": 1024,
        "stream": true,
      });

      final response = await request.send();
      
      if (response.statusCode == 200) {
        await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.isEmpty) continue;
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6);
            if (dataStr.trim() == '[DONE]') break;
            try {
              final decoded = jsonDecode(dataStr);
              final delta = decoded['choices'][0]['delta']['content'] ?? '';
              yield delta;
            } catch (_) {}
          }
        }
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        // FAILOVER: Switch to 8B model if 70B is rate-limited or overloaded
        debugPrint("Groq 70B Rate Limited. Falling back to 8B model...");
        final fallbackRequest = http.Request('POST', Uri.parse(_apiUrl));
        fallbackRequest.headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        });
        fallbackRequest.body = jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {"role": "system", "content": _buildSystemInstruction(contextToUse)},
            {"role": "user", "content": userPrompt}
          ],
          "temperature": 0.5,
          "max_tokens": 1024,
          "stream": true,
        });

        final fallbackResponse = await fallbackRequest.send();
        if (fallbackResponse.statusCode == 200) {
           await for (final line in fallbackResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
            if (line.isEmpty) continue;
            if (line.startsWith('data: ')) {
              final dataStr = line.substring(6);
              if (dataStr.trim() == '[DONE]') break;
              try {
                final decoded = jsonDecode(dataStr);
                final delta = decoded['choices'][0]['delta']['content'] ?? '';
                yield delta;
              } catch (_) {}
            }
          }
        } else {
          yield "I'm having trouble processing that right now.";
        }
      } else {
        final errorBody = await response.stream.bytesToString();
        debugPrint("Groq API Error ($response.statusCode): $errorBody");
        yield "I'm having trouble processing that right now.";
      }
    } catch (e) {
      debugPrint("AI Stream Error: $e");
      yield "Connection error. Please try again later.";
    }
  }

  static Future<String> generateTitle(String firstMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant", // Using a smaller model for titles
          "messages": [
            {
              "role": "system",
              "content": "You are a helpful assistant that generates extremely short, concise titles for chat conversations. Return ONLY the title (max 4 words). No punctuation, no quotes."
            },
            {"role": "user", "content": "Summarize this message into a 3-word title: $firstMessage"}
          ],
          "temperature": 0.5,
          "max_tokens": 10,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String title = data['choices'][0]['message']['content'] ?? "New Chat";
        title = title.replaceAll('"', '').replaceAll('.', '').trim();
        return title;
      }
      return "New Chat";
    } catch (e) {
      return "New Chat";
    }
  }

  static void init() {
    debugPrint("AiService initialized with Groq (Llama 3.3).");
  }
}
