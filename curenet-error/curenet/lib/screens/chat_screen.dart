import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import 'package:curenet/core/navigation_helper.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      "role": "bot",
      "text": "Namaste Priya! I'm Abhya, your personal health assistant. How can I help you today?"
    },
  ];

  final Map<String, String> _sampleResponses = {
    "What medications am I on?": "You're currently on **Amlodipine 5mg** once daily for hypertension. Last prescribed by Dr. Meena Kapoor on 22 Feb 2026. Take it every morning with water.",
    "Is my BP under control?": "Your last BP reading was **142/90 mmHg** (Stage 1). It's improving with medication. Keep monitoring and follow up with Dr. Kapoor in 4 weeks.",
    "When is my next appointment?": "Your cardiology follow-up with Dr. Meena Kapoor is due by **22 March 2026**. Would you like me to show the details?",
  };

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
    });
    _controller.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 600), () {
      final reply = _sampleResponses[text] ??
          "Based on your records, that's a great question! Let me check... For anything specific, I recommend discussing with your doctor. How else can I help?";
      setState(() {
        _messages.add({"role": "bot", "text": reply});
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendStarter(String question) {
    setState(() {
      _messages.add({"role": "user", "text": question});
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 700), () {
      final reply = _sampleResponses[question] ?? "Thank you for asking! Here's what I found in your records...";
      setState(() {
        _messages.add({"role": "bot", "text": reply});
      });
      _scrollToBottom();
    });
  }

  // NEW: Message bubble with speaker icon
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
            child: TranslatedText(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isUser ? Colors.white : const Color(0xFF0D2240),
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
              const Icon(Icons.more_horiz, color: Color(0xFF9BA8BB)),
            ],
          ),
        ),


        // Messages with speaker icons
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg["role"] == "user";
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUser)
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 22),
                        onPressed: () async {
                          final ok = await VoiceHelper.speak(msg["text"]);
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
                      ),
                      child: TranslatedText(
                        msg["text"],
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isUser ? Colors.white : const Color(0xFF0D2240),
                        ),
                      ),
                    ),
                    if (isUser)
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 22),
                        onPressed: () async {
                          final ok = await VoiceHelper.speak(msg["text"]);
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
            },
          ),
        ),

          // Starter Questions (unchanged)
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
                _starterChip("What medications am I on?"),
                _starterChip("Is my BP under control?"),
                _starterChip("When is my next appointment?"),
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