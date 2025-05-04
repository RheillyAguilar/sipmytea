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

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _saveAccount = false;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  List<Map<String, String>> _savedAccounts = [];
  final List<String> _profileImages = [
    'assets/profile1.jpg',
    'assets/profile2.jpg',
    'assets/profile3.jpg',
    'assets/profile4.jpg',
    'assets/profile5.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('savedAccounts') ?? [];

    setState(() {
      _savedAccounts =
          saved
              .map((entry) => Map<String, String>.from(jsonDecode(entry)))
              .toList();
    });
  }

  Future<void> _removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('savedAccounts') ?? [];

    saved.removeWhere((entry) => jsonDecode(entry)['email'] == email);
    await prefs.setStringList('savedAccounts', saved);

    _loadSavedAccounts();
  }

  Future<void> _login({String? email, String? password}) async {
    final emailText = email ?? _emailController.text.trim();
    final passwordText = password ?? _passwordController.text;

    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('account')
              .where('email', isEqualTo: emailText)
              .where('password', isEqualTo: passwordText)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userData = querySnapshot.docs.first.data();
        final isAdmin = userData['admin'] ?? false;
        final rawUsername = userData['username'] ?? '';
        final username =
            rawUsername.isNotEmpty
                ? rawUsername[0].toUpperCase() + rawUsername.substring(1)
                : '';

        if (_saveAccount) {
          List<String> saved = prefs.getStringList('savedAccounts') ?? [];
          saved.removeWhere((e) => jsonDecode(e)['email'] == emailText);

          Map<String, String> newAccount = {
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
            builder:
                (context) => MainPage(isAdmin: isAdmin, username: username),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Widget _buildSavedAccountsUI() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        physics: NeverScrollableScrollPhysics(),
        children: [
          ..._savedAccounts.map((account) {
            return GestureDetector(
              onTap:
                  () => _login(
                    email: account['email'],
                    password: account['password'],
                  ),
              onLongPress: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Remove account'),
                        content: Text(
                          'Do you want to remove ${account['username']}?',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _removeAccount(account['email'] ?? '');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B8673),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                            ),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: AssetImage(
                      account['image'] ?? _profileImages[0],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (account['username'] ?? '').isNotEmpty
                        ? account['username']![0].toUpperCase() +
                            account['username']!.substring(1)
                        : '',
                  ),
                ],
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              setState(() {
                _savedAccounts.clear();
              });
            },
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
                child:
                    _savedAccounts.isNotEmpty
                        ? _buildSavedAccountsUI()
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/sipmytea_logo.png',
                              height: 120,
                            ),
                            const SizedBox(height: 32),
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.person),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Checkbox(
                                  value: _saveAccount,
                                  onChanged: (value) {
                                    setState(() {
                                      _saveAccount = value!;
                                    });
                                  },
                                  activeColor: const Color(0xFF4B8673),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const Text(
                                  'Save account',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: const Color(0xFF4B8673),
                                ),
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
