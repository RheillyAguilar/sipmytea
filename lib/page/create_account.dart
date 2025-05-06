// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key});

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isAdmin = false;
  bool _obscurePassword = true;

  void _resetForm() {
    _emailController.clear();
    _passwordController.clear();
    _usernameController.clear();
    _isAdmin = false;
    _obscurePassword = true;
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF6F6F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _deleteAccount(String docId) async {
    await FirebaseFirestore.instance.collection('account').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deleted')),
    );
  }

  Future<bool?> _confirmDeletionDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                Text('Are sure to delete this account?', style: TextStyle(fontSize: 15),)
              ],
            ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4b8673),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountListTile(Map<String, dynamic> data, String docId, bool isAdmin) {
    final listTile = ListTile(
      leading: Icon(isAdmin ? Icons.verified_user : Icons.person, color: isAdmin ? Colors.blue : Colors.grey),
      title: Text(data['username'] ?? 'No Username'),
      subtitle: Text(data['email'] ?? 'No Email'),
      trailing: Text(
        isAdmin ? 'Admin' : 'User',
        style: TextStyle(color: isAdmin ? Colors.blue : Colors.black54),
      ),
    );

    if (isAdmin) return listTile;

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(Icons.delete, Alignment.centerLeft),
      secondaryBackground: _buildDismissBackground(Icons.delete, Alignment.centerRight),
      confirmDismiss: (direction) => _confirmDeletionDialog(context),
      onDismissed: (_) => _deleteAccount(docId),
      child: listTile,
    );
  }

  Widget _buildDismissBackground(IconData icon, Alignment alignment) {
    return Container(
      color: Colors.red,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('account').add({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'admin': _isAdmin,
      });
      _resetForm();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
    }
  }

  void _showCreateAccountForm() {
    bool tempAdmin = _isAdmin;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Create Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _usernameController,
                        decoration: _inputDecoration('Username', Icons.person),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter a username' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDecoration('Email', Icons.email),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter an email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          'Password',
                          Icons.lock,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setModalState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter a password' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Admin:', style: TextStyle(fontSize: 18)),
                          Switch(
                            value: tempAdmin,
                            onChanged: (value) => setModalState(() => tempAdmin = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isAdmin = tempAdmin);
                          _createAccount();
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF4B8673),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Create Account', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          _resetForm();
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor: Colors.grey[700],
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Create Account')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('account').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No Account Available', style: TextStyle(fontSize: 18, color: Colors.black54)),
            );
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isAdmin = data['admin'] == true;
              return _buildAccountListTile(data, doc.id, isAdmin);
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4b8673),
        onPressed: _showCreateAccountForm,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
