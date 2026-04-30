import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import '../core/app_language.dart';
import '../services/ai_service.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curenet/core/navigation_helper.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isTyping = false;
  bool _isListening = false;

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  String _currentSessionId = "";

  @override
  void initState() {
    super.initState();
    AiService.init();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('chat_sessions');
    
    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(sessionsJson);
      _sessions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    
    if (_sessions.isEmpty) {
      // Migrate old format if exists
      final String? oldHistory = prefs.getString('chat_history');
      if (oldHistory != null && oldHistory.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(oldHistory);
        _messages = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
        _sessions.add({
          "id": _currentSessionId,
          "title": "Previous Chat",
          "messages": _messages,
        });
        await _saveHistory();
        setState(() {});
        _scrollToBottom();
      } else {
        _createNewSession();
      }
    } else {
      _currentSessionId = _sessions.last['id'] as String;
      _messages = List<Map<String, dynamic>>.from(_sessions.last['messages']);
      setState(() {});
      _scrollToBottom();
    }
  }

  void _createNewSession() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSessionId = newId;
    _messages = [
      {
        "role": "bot",
        "text": "Namaste Priya! I'm Abhya, your personal health assistant. How can I help you today?"
      },
    ];
    _sessions.add({
      "id": newId,
      "title": "New Chat",
      "messages": _messages,
    });
    setState(() {});
    _saveHistory();
  }

  void _switchSession(String id) {
    final session = _sessions.firstWhere((s) => s['id'] == id);
    setState(() {
      _currentSessionId = id;
      _messages = List<Map<String, dynamic>>.from(session['messages']);
    });
    _scrollToBottom();
  }

  Future<void> _saveHistory() async {
    if (_messages.length > 1) {
      final sessionIndex = _sessions.indexWhere((s) => s['id'] == _currentSessionId);
      if (sessionIndex != -1) {
        if (_sessions[sessionIndex]['title'] == "New Chat") {
           final firstUserMsg = _messages.firstWhere((m) => m['role'] == 'user', orElse: () => {"text": "New Chat"})['text'] as String;
           final title = (firstUserMsg.length > 20) ? "\${firstUserMsg.substring(0, 20)}..." : firstUserMsg;
           _sessions[sessionIndex]['title'] = title;
        }
        _sessions[sessionIndex]['messages'] = _messages;
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_sessions', jsonEncode(_sessions));
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => print('onError: \$val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_controller.text.isNotEmpty) {
        _sendMessage();
      }
    }
  }

  Future<String> _getPatientContext() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('health_records');
    final String? abhaAddress = prefs.getString('abha_address') ?? 'Not provided';
    final String? userName = prefs.getString('user_name') ?? 'Priya Sharma'; // Fallback to Priya for demo

    String context = "[PATIENT_PROFILE]\nName: $userName\nABHA: $abhaAddress\n\n[MEDICAL_RECORDS]\n";
    
    if (recordsJson != null && recordsJson.isNotEmpty) {
      final List<dynamic> records = jsonDecode(recordsJson);
      for (var r in records) {
        context += "- ${r['date']}: ${r['title']} (Doctor: ${r['doctor']}, Category: ${r['category']})\n";
      }
    } else {
      context += "No local records found.";
    }
    
    context += "\n[/MEDICAL_RECORDS]";
    return context;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _saveHistory();
    _controller.clear();
    _scrollToBottom();

    final languageCode = AppLanguage.selectedLanguage.value;
    final patientContext = await _getPatientContext();
    final reply = await AiService.sendMessage(
      text, 
      language: languageCode, 
      patientContext: patientContext,
    );
    
    if (!mounted) return;
    setState(() {
      _messages.add({"role": "bot", "text": reply});
      _isTyping = false;
    });
    _saveHistory();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendStarter(String question) async {
    setState(() {
      _messages.add({"role": "user", "text": question});
      _isTyping = true;
    });
    _saveHistory();
    _scrollToBottom();

    final languageCode = AppLanguage.selectedLanguage.value;
    final patientContext = await _getPatientContext();
    final reply = await AiService.sendMessage(
      question, 
      language: languageCode,
      patientContext: patientContext,
    );
    
    if (!mounted) return;
    setState(() {
      _messages.add({"role": "bot", "text": reply});
      _isTyping = false;
    });
    _saveHistory();
    _scrollToBottom();
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isUser = msg["role"] == "user";
    final text = msg["text"] as String;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            IconButton(
              icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 20),
              onPressed: () async {
                final plainText = text.replaceAll(RegExp(r'\*|#'), '');
                final ok = await VoiceHelper.speak(plainText);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(VoiceHelper.lastError ?? 'Voice readout failed.'),
                      backgroundColor: const Color(0xFF0D2240),
                    ),
                  );
                }
              },
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF00A3A3) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isUser
                ? TranslatedText(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  )
                : MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Color(0xFF0D2240),
                      ),
                      strong: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00A3A3),
                      ),
                    ),
                  ),
          ),
          if (isUser)
            IconButton(
              icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 20),
              onPressed: () async {
                final ok = await VoiceHelper.speak(text);
                if (!ok && mounted) {
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
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    body: Column(
      children: [
        // Header (unchanged)
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
                child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFE07B39),
                child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText("Abhya AI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  TranslatedText("Always here • 24×7", style: TextStyle(fontSize: 10, color: Color(0xFF22A36A))),
                ],
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Color(0xFF9BA8BB)),
                onSelected: (value) {
                  if (value == 'new') {
                    _createNewSession();
                  } else {
                    _switchSession(value);
                  }
                },
                itemBuilder: (context) {
                  List<PopupMenuEntry<String>> items = [
                    const PopupMenuItem(
                      value: 'new',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 8),
                          Text("New Chat"),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ];
                  
                  // Add past sessions in reverse order (newest first)
                  for (var session in _sessions.reversed) {
                    items.add(
                      PopupMenuItem(
                        value: session['id'] as String,
                        child: Text(
                          session['title'] as String,
                          style: TextStyle(
                            fontWeight: session['id'] == _currentSessionId ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }
                  return items;
                },
              ),
            ],
          ),
        ),


        // Messages with speaker icons
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12, left: 40),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A3A3)),
                      ),
                    ),
                  ),
                );
              }
              final msg = _messages[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),

          // Starter Questions (Hide after first interaction)
          if (_messages.length <= 1)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _starterChip("Emergency Snapshot"),
                  _starterChip("Simplify my latest lab report"),
                  _starterChip("Any side effects with my medicines?"),
                  _starterChip("Summarize my last doctor's visit"),
                ],
              ),
            ),

          // Input Bar (unchanged)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask anything about your health...",
                      hintStyle: const TextStyle(color: Color(0xFF9BA8BB)),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _listen,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : const Color(0xFFE8F7F7),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.white : const Color(0xFF00A3A3),
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A3A3),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.send, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _starterChip(String text) {
    return GestureDetector(
      onTap: () => _sendStarter(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F7F7),
          borderRadius: BorderRadius.circular(30),
        ),
        child: TranslatedText(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D2240)),
        ),
      ),
    );
  }
}