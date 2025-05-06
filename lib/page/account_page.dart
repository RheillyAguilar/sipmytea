// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipmytea/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _saveAccount = false;

  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  final _profileImages = List.generate(6, (i) => 'assets/profile${i + 1}.jpg');
  List<Map<String, String>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('savedAccounts') ?? [];
    setState(() {
      _savedAccounts = saved.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
    });
  }

  Future<void> _removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('savedAccounts') ?? [];
    saved.removeWhere((entry) => jsonDecode(entry)['email'] == email);
    await prefs.setStringList('savedAccounts', saved);
    _loadSavedAccounts();
  }

  Future<void> _login({String? email, String? password}) async {
    final emailText = email ?? _emailController.text.trim();
    final passwordText = password ?? _passwordController.text;

    try {
      final query = await FirebaseFirestore.instance
          .collection('account')
          .where('email', isEqualTo: emailText)
          .where('password', isEqualTo: passwordText)
          .get();

      if (query.docs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final user = query.docs.first.data();
        final isAdmin = user['admin'] ?? false;
        final username = _capitalize(user['username'] ?? '');

        if (_saveAccount) {
          final saved = prefs.getStringList('savedAccounts') ?? [];
          saved.removeWhere((e) => jsonDecode(e)['email'] == emailText);
          final newAccount = {
            'email': emailText,
            'password': passwordText,
            'username': username,
            'image': _profileImages[Random().nextInt(_profileImages.length)],
          };
          saved.add(jsonEncode(newAccount));
          await prefs.setStringList('savedAccounts', saved);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainPage(isAdmin: isAdmin, username: username),
          ),
        );
      } else {
        _showSnackbar('Invalid email or password');
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}');
    }
  }

  String _capitalize(String input) =>
      input.isNotEmpty ? input[0].toUpperCase() + input.substring(1) : '';

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildAccountAvatar(Map<String, String> account) {
    return GestureDetector(
      onTap: () => _login(email: account['email'], password: account['password']),
      onLongPress: () => _confirmRemoveAccount(account),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage: AssetImage(account['image'] ?? _profileImages[0]),
          ),
          const SizedBox(height: 8),
          Text((account['username'] ?? '').split(' ').first),
        ],
      ),
    );
  }

  void _confirmRemoveAccount(Map<String, String> account) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 40,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Alert',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text('Are sure to remove this account?', style: TextStyle(fontSize: 15),)
              ],
            ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeAccount(account['email'] ?? '');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B8673),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAccountsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ..._savedAccounts.map(_buildAccountAvatar),
        GestureDetector(
          onTap: () => setState(() => _savedAccounts.clear()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircleAvatar(
                radius: 35,
                backgroundColor: Color(0xFF4B8673),
                child: Icon(Iconsax.add, size: 40, color: Colors.white),
              ),
              SizedBox(height: 8),
              Text("Add account"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/sipmytea_logo.png', height: 120),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.person,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: _saveAccount,
              onChanged: (value) => setState(() => _saveAccount = value!),
              activeColor: const Color(0xFF4B8673),
            ),
            const Text('Save account', style: TextStyle(fontSize: 15)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B8673),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log in', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFdfebe6),
      body: Center(
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _savedAccounts.isNotEmpty ? _buildSavedAccountsGrid() : _buildLoginForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
