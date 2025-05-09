import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';


class StockPage extends StatefulWidget {
  final bool isAdmin;
  const StockPage({super.key, required this.isAdmin});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _limitController = TextEditingController();

  String _selectedType = '';
  String _selectedCategory = 'Raw';
  bool isLoading = true;
  final List<String> _categories = ['Raw', 'Milktea', 'Syrup', 'Powder', 'Other'];
  
     // Helper function to capitalize the first letter of a string
  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _numberController.clear();
    _limitController.clear();
    _selectedType = '';
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

  void _showAddStockSheet({
    String? docId,
    String? initialName,
    String? initialQuantity,
    String? initialLimit,
    String? initialType,
  }) {
    _nameController.text = initialName ?? '';
    _numberController.text = initialQuantity ?? '';
    _limitController.text = initialLimit ?? '';
    _selectedType = initialType ?? '';

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
          child: _buildStockForm(docId),
        );
      },
    );
  }

  Widget _buildStockForm(String? docId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          docId != null ? 'Edit Stock' : 'Add New Stock',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 16),
        TextField(
          controller: _limitController,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('Limit'),
        ),
        const SizedBox(height: 16),
       DropdownButtonFormField<String>(
        value: _selectedType.isNotEmpty ? _selectedType : null,
        decoration: _inputDecoration('Type'),
        items: _categories
            .map(
              (type) => DropdownMenuItem(
                value: type,
                child: Text(type),),
                ).toList(),
        onChanged: (value) => setState(() => _selectedType = value ?? ''),),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _submitStockForm(docId),
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
    );
  }

  Future<void> _submitStockForm(String? docId) async {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: LoadingAnimationWidget.fallingDot(
                color: Colors.white,
                size: 80,
              ),
            ),
          ));
    try {
      final name = capitalizeFirstLetter(_nameController.text.trim());
    final number = _numberController.text.trim();
    final limit = _limitController.text.trim();

    if ([name, number, limit, _selectedType].any((e) => e.isEmpty)) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please input all fields'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('stock').doc(name.toLowerCase());
    final inputQuantity = int.tryParse(number) ?? 0;
    final inputLimit = int.tryParse(limit) ?? 0;
    final doc = await docRef.get();

    if (docId != null) {
      await docRef.set({
        'name': name,
        'quantity': inputQuantity,
        'limit': inputLimit,
        'type': _selectedType,
      });
    } else {
      int currentQuantity =
          doc.exists ? int.tryParse(doc['quantity']) ?? 0 : 0;
      await docRef.set({
        'name': name,
        'quantity': (currentQuantity + inputQuantity),
        'limit': inputLimit,
        'type': _selectedType,
      });
    }
Navigator.pop(context); // closes the bottom sheet

    Navigator.pop(context);
    _resetForm();
    } catch (e) {
       Navigator.pop(context); // dismiss loading in case of error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save data: $e')),
    );
    }
  }

  Future<void> _confirmDelete(String docId) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Delete Stock?'),
                content: const Text('Are you sure to delete this stock?'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4B8673),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
              ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('stock').doc(docId).delete();
    }
  }

Widget _buildStockList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('stock').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: LoadingAnimationWidget.fallingDot(
            color: const Color(0xFF4b8673),
            size: 80,
          ),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(child: Text('No stocks yet.'));
      }

      var stocks = snapshot.data!.docs;
      if (_selectedCategory != 'All') {
        stocks = stocks.where((doc) => doc['type'] == _selectedCategory).toList();
      }

      if (stocks.isEmpty) {
        return const Center(child: Text('No items in this category.'));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: stocks.length,
        itemBuilder: (context, index) {
          final stock = stocks[index];
          return _buildStockTile(stock);
        },
      );
    },
  );
}


  Widget _buildStockTile(QueryDocumentSnapshot stock) {
    final name = stock['name'];
    final quantity = stock['quantity'];
    final limit = stock['limit'] ?? '';
    final type = stock['type'] ?? 'N/A';

    final int qty = int.tryParse(quantity.toString()) ?? 0;
    final int lim = int.tryParse(limit.toString()) ?? 0;
    final bool isLow = qty <= lim;
    final card = Card(
      color: isLow ? Colors.red.shade100 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: ListTile(
        leading: Icon(
          isLow ? Icons.warning_amber_rounded : Iconsax.box,
          color: isLow ? Colors.red : const Color(0xFF4B8673),
          size: 30,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Quantity: $quantity\nLimit: $limit'),
      ),
    );

    return widget.isAdmin
        ? Slidable(
          key: ValueKey(name),
          startActionPane: _buildActionPane(
            stock.id,
            name,
            quantity.toString(),
            limit.toString(),
            type,
          ),
          endActionPane: _buildActionPane(
            stock.id,
            name,
            quantity.toString(),
            limit.toString(),
            type,
          ),
          child: card,
        )
        : card;
  }

  ActionPane _buildActionPane(
    String docId,
    String name,
    String quantity,
    String limit,
    String type,
  ) {
    return ActionPane(
      motion: const DrawerMotion(),
      children: [
        SlidableAction(
          onPressed:
              (_) => _showAddStockSheet(
                docId: docId,
                initialName: name,
                initialQuantity: quantity,
                initialLimit: limit,
                initialType: type,
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

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedCategory = category),
            selectedColor: const Color(0xFF4B8673),
            backgroundColor: Colors.grey.shade200,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
            ),
          );
        },
      ),
    );
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
      body: Column(
        children: [_buildCategoryChips(), Expanded(child: _buildStockList())],
      ),
      floatingActionButton:
          widget.isAdmin
              ? FloatingActionButton(
                onPressed: () => _showAddStockSheet(),
                backgroundColor: const Color(0xFF4B8673),
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }
}
