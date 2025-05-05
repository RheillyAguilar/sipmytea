// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class FinishedPage extends StatefulWidget {
  const FinishedPage({super.key});

  @override
  State<FinishedPage> createState() => _FinishedPageState();
}

class _FinishedPageState extends State<FinishedPage> {
  final CollectionReference finishedGoodsRef = FirebaseFirestore.instance
      .collection('finished_goods');

void _showAddFinishedGoodModal() {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  List<MapEntry<TextEditingController, TextEditingController>> ingredientControllers = [
    MapEntry(TextEditingController(), TextEditingController())
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add Finished Good',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      filled: true,
                      fillColor: Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      filled: true,
                      fillColor: Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  ...ingredientControllers.asMap().entries.map((entry) {
                    int index = entry.key;
                    TextEditingController nameCtrl = entry.value.key;
                    TextEditingController qtyCtrl = entry.value.value;
                    return Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 8),
                            child: TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Name',
                                filled: true,
                                fillColor: Color(0xFFF7F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                filled: true,
                                fillColor: Color(0xFFF7F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (ingredientControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                ingredientControllers.removeAt(index);
                              });
                            },
                          ),
                      ],
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        ingredientControllers.add(
                          MapEntry(TextEditingController(), TextEditingController()),
                        );
                      });
                    },
                    icon: const Icon(Icons.add, color: Color(0xFF4B8673)),
                    label: const Text('Add Ingredient', style: TextStyle(color: Color(0xFF4B8673))),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      String name = nameController.text.trim();
                      String quantity = quantityController.text.trim();

                      if (name.isEmpty || quantity.isEmpty || ingredientControllers.any((pair) => pair.key.text.trim().isEmpty || pair.value.text.trim().isEmpty)) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in all fields')),
                        );
                        return;
                      }

                      try {
                        int qty = int.tryParse(quantity) ?? 0;
                        List<Map<String, dynamic>> ingredients = ingredientControllers.map((pair) {
                          return {
                            'name': pair.key.text.trim(),
                            'quantity': int.tryParse(pair.value.text.trim()) ?? 0,
                          };
                        }).toList();

                        final docRef = finishedGoodsRef.doc(name);
                        final docSnapshot = await docRef.get();

                        if (docSnapshot.exists) {
                          int currentQty = docSnapshot['quantity'] ?? 0;
                          await docRef.update({
                            'quantity': currentQty + qty,
                            'ingredients': ingredients,
                          });
                        } else {
                          await docRef.set({
                            'name': name,
                            'quantity': qty,
                            'ingredients': ingredients,
                          });
                        }

                        Navigator.pop(context);
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF4B8673),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finished Goods')),
      body: StreamBuilder<QuerySnapshot>(
        stream: finishedGoodsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Iconsax.document, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No finished good yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final item = docs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                color: const Color(0xFFF0F5F2),
                child: ListTile(
                  leading: const Icon(
                    Iconsax.document,
                    color: Color(0xFF4B8673),
                  ),
                  title: Text(
                    item.id,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                 subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Quantity: ${item['quantity']}'),
    const SizedBox(height: 4),
    if (item['ingredients'] != null && item['ingredients'] is List)
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (item['ingredients'] as List).length == 1 ? 'Ingredient:' : 'Ingredients:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          ...List<Widget>.from((item['ingredients'] as List).map((ingredient) {
            return Text(
              '${ingredient['name']} - ${ingredient['quantity']}',
              style: const TextStyle(fontSize: 12),
            );
          })),
        ],
      ),
  ],
),



                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFinishedGoodModal,
        backgroundColor: const Color(0xFF4B8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
