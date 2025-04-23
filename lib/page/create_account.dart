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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  bool isAdmin = false;
  bool _obscurePassword = true;

  void _resetForm() {
    emailController.clear();
    passwordController.clear();
    usernameController.clear();
    isAdmin = false;
    _obscurePassword = true;
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
              child: Text(
                'No Account Available',
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isUserAdmin = data['admin'] == true;

              final listTile = ListTile(
                leading: Icon(
                  isUserAdmin ? Icons.verified_user : Icons.person,
                  color: isUserAdmin ? Colors.blue : Colors.grey,
                ),
                title: Text(data['username'] ?? 'No Username'),
                subtitle: Text(data['email'] ?? 'No Email'),
                trailing: Text(
                  isUserAdmin ? 'Admin' : 'User',
                  style: TextStyle(
                    color: isUserAdmin ? Colors.blue : Colors.black54,
                  ),
                ),
              );

              if (isUserAdmin) {
                return listTile;
              }

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.horizontal,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text("Confirm Deletion"),
                      content: const Text("Are you sure you want to delete this account?"),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            )
                          ),
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                         TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700]
                          ),
                          child: const Text("Cancel"),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) async {
                  await FirebaseFirestore.instance
                      .collection('account')
                      .doc(doc.id)
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted')),
                  );
                },
                child: listTile,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          bool tempIsAdmin = isAdmin;

          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Create Account'),
                content: StatefulBuilder(
                  builder: (context, setState) {
                    return SizedBox(
                      width: 900,
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextFormField(
                                controller: usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person),
                                  filled: true,
                                  fillColor: Color(0xFFF6F6F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none
                                  )
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                  filled: true,
                                  fillColor: Color(0xFFF6F6F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none
                                  )
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  filled: true,
                                  fillColor: Color(0xFFF6F6F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const Text('Admin:', style: TextStyle(fontSize: 20)),
                                  Switch(
                                    value: tempIsAdmin,
                                    onChanged: (value) {
                                      setState(() {
                                        tempIsAdmin = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          isAdmin = tempIsAdmin;
                        });

                        await FirebaseFirestore.instance
                            .collection('account')
                            .add({
                          'username': usernameController.text.trim(),
                          'email': emailController.text.trim(),
                          'password': passwordController.text.trim(),
                          'admin': isAdmin,
                        });

                        _resetForm();
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Account created successfully!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4B8673),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      )
                    ),
                    child: const Text(
                      'Create',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _resetForm();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700]
                    ),
                    child: const Text('Cancel', ),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add, color: Color(0xFF4B8673),),
      ),
    );
  }
}
