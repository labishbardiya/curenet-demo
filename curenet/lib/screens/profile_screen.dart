import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, String> userData = Map<String, String>.from(Persona.profileMap);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('user_profile_data');
    if (savedData != null) {
      setState(() {
        userData = Map<String, String>.from(jsonDecode(savedData));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_data', jsonEncode(userData));
    
    // Also update common keys used by AI/Snapshot
    await prefs.setString('user_name', userData['name']!);
    await prefs.setString('abha_address', userData['abha']!);
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: userData['name']);
    final mobileCtrl = TextEditingController(text: userData['mobile']);
    final bloodCtrl = TextEditingController(text: userData['bloodGroup']);
    final allergiesCtrl = TextEditingController(text: userData['allergies']);
    final emergencyCtrl = TextEditingController(text: userData['emergencyContact']);
    final conditionsCtrl = TextEditingController(text: userData['conditions']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText("Edit Health Profile"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _editField("Full Name", nameCtrl),
              _editField("Mobile Number", mobileCtrl),
              _editField("Blood Group", bloodCtrl),
              _editField("Allergies", allergiesCtrl),
              _editField("Emergency Contact", emergencyCtrl),
              _editField("Medical Conditions", conditionsCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const TranslatedText("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                userData['name'] = nameCtrl.text;
                userData['mobile'] = mobileCtrl.text;
                userData['bloodGroup'] = bloodCtrl.text;
                userData['allergies'] = allergiesCtrl.text;
                userData['emergencyContact'] = emergencyCtrl.text;
                userData['conditions'] = conditionsCtrl.text;
              });
              _saveUserData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: TranslatedText("Profile updated successfully!"), backgroundColor: Color(0xFF00A3A3)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A3A3)),
            child: const TranslatedText("Save"),
          ),
        ],
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Navy Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0D2240), Color(0xFF1A3A5C)]),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                const TranslatedText("My Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                const Spacer(),
                IconButton(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit, color: Colors.white),
                ),
              ],
            ),
          ),

          // Profile Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(color: Color(0xFF00A3A3), shape: BoxShape.circle),
                  child: Center(
                    child: Text(userData['name']![0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(userData['name']!, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0D2240))),
                      Text("ABHA: ${userData['abha']}", style: const TextStyle(fontSize: 13, color: Color(0xFF00C4C4))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildCard(
                    title: "HEALTH INFORMATION",
                    children: [
                      _infoRow("Date of Birth", userData['dob']!),
                      _infoRow("Mobile", userData['mobile']!),
                      _infoRow("Blood Group", userData['bloodGroup']!),
                      _infoRow("Allergies", userData['allergies']!),
                      _infoRow("Emergency Contact", userData['emergencyContact']!),
                      _infoRow("Conditions", userData['conditions']!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    title: "DOCTOR ACCESS LOG",
                    children: [
                      _accessRow("Dr. Suresh Kumar", "Apollo Spectra · Today 11:41 AM", "Active"),
                      const Divider(height: 1, color: Color(0xFFD8DDE6)),
                      _accessRow("Dr. Meena Kapoor", "Apollo Spectra · 22 Feb 2026", "Expired"),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TranslatedText(label, style: const TextStyle(fontSize: 14, color: Color(0xFF5A6880))),
          Flexible(child: TranslatedText(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _accessRow(String doctor, String subtitle, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(doctor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                TranslatedText(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: status == "Active" ? const Color(0xFFE6F7EF) : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TranslatedText(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status == "Active" ? const Color(0xFF22A36A) : const Color(0xFF9BA8BB))),
          ),
        ],
      ),
    );
  }
}