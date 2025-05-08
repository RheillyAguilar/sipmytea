import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iconsax/iconsax.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class FinishedPage extends StatefulWidget {
  const FinishedPage({super.key});

  @override
  State<FinishedPage> createState() => _FinishedPageState();
}

class _FinishedPageState extends State<FinishedPage> {
  final CollectionReference finishedGoodsRef = FirebaseFirestore.instance
      .collection('finished_goods');
  final CollectionReference stockRef = FirebaseFirestore.instance.collection(
    'stock',
  );
  bool isLoading = true;

  // Utility method for creating text fields
  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Method for showing low stock warning
  Future<void> _showLowStockWarning(String itemName, int quantity) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _buildWarningDialog(itemName, quantity);
      },
    );
  }

  // Helper method to build warning dialog
  Widget _buildWarningDialog(String itemName, int quantity) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWarningIcon(),
            const SizedBox(height: 24),
            _buildWarningText(itemName, quantity),
            const SizedBox(height: 24),
            _buildAcknowledgeButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 64,
        color: Colors.red,
      ),
    );
  }

  Widget _buildWarningText(String itemName, int quantity) {
    return Column(
      children: [
        Text(
          'Low Stock Alert',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.red.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$itemName stock is low.\nOnly $quantity left.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
        ),
      ],
    );
  }

  Widget _buildAcknowledgeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Acknowledge'),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  // Helper function to capitalize the first letter of a string
  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _showFinishedGoodModal({DocumentSnapshot? item}) async {
    final TextEditingController nameController = TextEditingController(
      text: item?['name'],
    );
    final TextEditingController quantityController = TextEditingController(
      text: item?['quantity'].toString(),
    );
    final TextEditingController canDoController =
        TextEditingController(); // New controller for "Can Do"
    List<MapEntry<TextEditingController, TextEditingController>>
    ingredientControllers = _initializeIngredientControllers(item);

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
                    _buildModalTitle(item),
                    const SizedBox(height: 20),
                    _buildTextField(nameController, 'Name'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      quantityController,
                      'Quantity',
                      inputType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      canDoController,
                      'Can Do', // New label here
                      inputType: TextInputType.text,
                    ),
                    const SizedBox(height: 20),
                    _buildIngredientsSection(setState, ingredientControllers),
                    const SizedBox(height: 20),
                    _buildSaveButton(
                      item,
                      nameController,
                      quantityController,
                      ingredientControllers,
                      canDoController,
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

  Widget _buildModalTitle(DocumentSnapshot? item) {
    return Text(
      item == null ? 'Add Finished Good' : 'Edit Finished Good',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  List<MapEntry<TextEditingController, TextEditingController>>
  _initializeIngredientControllers(DocumentSnapshot? item) {
    return (item?['ingredients'] as List?)
            ?.map<MapEntry<TextEditingController, TextEditingController>>((
              ingredient,
            ) {
              return MapEntry(
                TextEditingController(text: ingredient['name']),
                TextEditingController(text: ingredient['quantity'].toString()),
              );
            })
            .toList() ??
        [MapEntry(TextEditingController(), TextEditingController())];
  }

  Widget _buildIngredientsSection(
    StateSetter setState,
    List<MapEntry<TextEditingController, TextEditingController>>
    ingredientControllers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Ingredients',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ...ingredientControllers.asMap().entries.map((entry) {
          return _buildIngredientRow(
            entry.key,
            entry.value,
            setState,
            ingredientControllers,
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
          label: const Text(
            'Add Ingredient',
            style: TextStyle(color: Color(0xFF4B8673)),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(
    int index,
    MapEntry<TextEditingController, TextEditingController> controllers,
    StateSetter setState,
    List<MapEntry<TextEditingController, TextEditingController>>
    ingredientControllers,
  ) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: _buildTextField(controllers.key, 'Name'),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: _buildTextField(
              controllers.value,
              'Quantity',
              inputType: TextInputType.number,
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
  }

  Widget _buildSaveButton(
    DocumentSnapshot? item,
    TextEditingController nameController,
    TextEditingController quantityController,
    List<MapEntry<TextEditingController, TextEditingController>>
    ingredientControllers,
    TextEditingController canDoController, // Accept new controller
  ) {
    return ElevatedButton(
      onPressed: () async {
        String name = capitalizeFirstLetter(nameController.text.trim());
        String quantity = quantityController.text.trim();
        String canDo = canDoController.text.trim(); // Get the "Can Do" text

        if (name.isEmpty ||
            quantity.isEmpty ||
            canDo.isEmpty || // Add check for "Can Do"
            ingredientControllers.any(
              (pair) =>
                  pair.key.text.trim().isEmpty ||
                  pair.value.text.trim().isEmpty,
            )) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all fields')),
          );
          return;
        }

        try {
          int qty = int.tryParse(quantity.toString()) ?? 0;
          int cando = int.tryParse(canDo.toString()) ?? 0;
          List<Map<String, dynamic>> ingredients =
              ingredientControllers.map((pair) {
                return {
                  'name': capitalizeFirstLetter(pair.key.text.trim()),
                  'quantity': int.tryParse(pair.value.text.trim()) ?? 0,
                };
              }).toList();

          List<String> missingOrLowStockMessages =
              await _checkStockAvailability(ingredients);
          if (missingOrLowStockMessages.isNotEmpty) {
            await _showStockInsufficientDialog(
              missingOrLowStockMessages,
              context,
            );
            return;
          }
          Navigator.pop(context);
          await _saveFinishedGood(item, name, qty, ingredients, cando);
        } catch (e) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: const Color(0xFF4B8673),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        item == null ? 'Add' : 'Save',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Future<List<String>> _checkStockAvailability(
    List<Map<String, dynamic>> ingredients,
  ) async {
    List<String> messages = [];
    for (var ing in ingredients) {
      DocumentReference stockDoc = stockRef.doc(ing['name'].toLowerCase());
      DocumentSnapshot stockSnapshot = await stockDoc.get();

      if (!stockSnapshot.exists) {
        messages.add('${ing['name']} is not on the stock.');
        continue;
      }

      int currentStockQty =
          int.tryParse(stockSnapshot.get('quantity').toString()) ?? 0;
      int requiredQty = ing['quantity'];
      if (currentStockQty < requiredQty) {
        messages.add(
          '${ing['name']} is not enough (have: $currentStockQty, need: $requiredQty).',
        );
      }
    }
    return messages;
  }

  Future<void> _showStockInsufficientDialog(
    List<String> messages,
    BuildContext context,
  ) async {
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 30,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Alert',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: messages.map((msg) => Text('- $msg')).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveFinishedGood(
    DocumentSnapshot? item,
    String name,
    int qty,
    List<Map<String, dynamic>> ingredients,
    int canDo,
  ) async {
    final docRef = finishedGoodsRef.doc(name);
    if (item != null) {
      await docRef.update({
        'quantity': qty,
        'ingredients': ingredients,
        'canDo': canDo,
      });
    } else {
      await docRef.set({
        'name': name,
        'quantity': qty,
        'ingredients': ingredients,
        'canDo': canDo,
      });
    }

    // Deduct stock for each ingredient based on the fixed total amount
    for (var ing in ingredients) {
      final ingName = ing['name'].toLowerCase();
      final totalRequiredQty = (ing['quantity'] as num).toInt();

      DocumentReference stockDoc = stockRef.doc(ingName);
      DocumentSnapshot stockSnapshot = await stockDoc.get();

      if (stockSnapshot.exists) {
        int currentQty =
            int.tryParse(stockSnapshot.get('quantity').toString()) ?? 0;
        int newQty = currentQty - totalRequiredQty;

        await stockDoc.update({'quantity': newQty});

        // Trigger low stock warning if needed
        var limitVal = stockSnapshot.get('limit');
        int limit =
            (limitVal is int)
                ? limitVal
                : int.tryParse(limitVal.toString()) ?? 0;

        if (newQty <= limit) {
          await _showLowStockWarning(ing['name'], newQty);
        }
      }
    }
  }

  // Helper method to show an empty state
  Widget _buildEmptyState() {
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
  return Center(
    child: LoadingAnimationWidget.fallingDot(
      color: Colors.green,
      size: 80,
    ),
  );
}


          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final item = docs[index];
              return Slidable(
                key: ValueKey(item.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed:
                          (context) => _showFinishedGoodModal(item: item),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'Edit',
                    ),
                    SlidableAction(
                      onPressed: (context) => _confirmDelete(item.id),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed:
                          (context) => _showFinishedGoodModal(item: item),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'Edit',
                    ),
                    SlidableAction(
                      onPressed: (context) => _confirmDelete(item.id),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: _buildFinishedGoodCard(item),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFinishedGoodModal(),
        backgroundColor: const Color(0xFF4B8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFinishedGoodCard(DocumentSnapshot item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Iconsax.document_normal,
                  color: Color(0xFF4B8673),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${item['name']} | ${item['quantity']} | ${item['canDo']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item['ingredients'] != null && item['ingredients'] is List)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingredients:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...List<Widget>.from(
                    (item['ingredients'] as List).map((ingredient) {
                      return Text(
                        '• ${ingredient['name']} - ${ingredient['quantity']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      );
                    }),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Delete Finished Goods?'),
            content: const Text('Are you sure to delete this finished goods?'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B8673),
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
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await finishedGoodsRef.doc(docId).delete();
    }
  }
}
