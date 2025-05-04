import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  void _showAddStockSheet({
    String? docId,
    String? initialName,
    String? initialQuantity,
  }) {
    _nameController.text = initialName ?? '';
    _numberController.text = initialQuantity ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  docId != null ? 'Edit Stock' : 'Add New Stock',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Quantity'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    String name = _nameController.text.trim();
                    String number = _numberController.text.trim();

                    if (name.isNotEmpty && number.isNotEmpty) {
                      final docRef = FirebaseFirestore.instance
                          .collection('stock')
                          .doc(name);
                      final doc = await docRef.get();

                      int inputQuantity = int.tryParse(number) ?? 0;

                      if (docId != null) {
                        // Edit mode: update to the new quantity directly
                        await docRef.set({
                          'name': name,
                          'quantity': inputQuantity.toString(),
                        });
                      } else {
                        // Add mode: sum with existing if it exists
                        int currentQuantity = 0;
                        if (doc.exists) {
                          currentQuantity = int.tryParse(doc['quantity'].toString()) ?? 0;
                        }

                        await docRef.set({
                          'name': name,
                          'quantity':
                              (currentQuantity + inputQuantity).toString(),
                        });
                      }

                      Navigator.pop(context);
                      _nameController.clear();
                      _numberController.clear();
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF4B8673),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    docId != null ? 'Save' : 'Add',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _confirmDelete(String docId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Stock?'),
              content: const Text('Are you sure to delete this stock?'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('stock').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stock',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stock').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Iconsax.box, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No stocks yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final stocks = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stocks.length,
            itemBuilder: (context, index) {
              final stock = stocks[index];
              final name = stock['name'];
              final quantity = stock['quantity'];

              return Slidable(
                key: ValueKey(name),
                startActionPane: _buildActionPane(stock.id, name, quantity),
                endActionPane: _buildActionPane(stock.id, name, quantity),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  child: ListTile(
                    leading: const Icon(Iconsax.box, color: Color(0xFF4B8673)),
                    title: Text(
                      name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Quantity: $quantity',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStockSheet(),
        backgroundColor: const Color(0xFF4B8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  ActionPane _buildActionPane(String docId, String name, String quantity) {
    return ActionPane(
      motion: const DrawerMotion(),
      children: [
        SlidableAction(
          onPressed:
              (_) => _showAddStockSheet(
                docId: docId,
                initialName: name,
                initialQuantity: quantity,
              ),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          icon: Icons.edit,
          label: 'Edit',
        ),
        SlidableAction(
          onPressed: (_) => _confirmDelete(docId),
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          icon: Icons.delete,
          label: 'Delete',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }
}
