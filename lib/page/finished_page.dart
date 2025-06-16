import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iconsax/iconsax.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class FinishedPage extends StatefulWidget {
  final bool isAdmin;
  const FinishedPage({super.key, required this.isAdmin});

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
    final TextEditingController canDoController =
        TextEditingController(text: item?['canDo'].toString());
    
    // Store original ingredients for comparison during edit
    List<Map<String, dynamic>> originalIngredients = [];
    if (item != null && item['ingredients'] != null) {
      originalIngredients = List<Map<String, dynamic>>.from(
        (item['ingredients'] as List).map((ing) => {
          'name': ing['name'],
          'quantity': ing['quantity'],
        })
      );
    }
    
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
                      canDoController,
                      'Can Do',
                      inputType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildIngredientsSection(setState, ingredientControllers),
                    const SizedBox(height: 20),
                    _buildSaveButton(
                      item,
                      nameController,
                      ingredientControllers,
                      canDoController,
                      originalIngredients,
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
    List<MapEntry<TextEditingController, TextEditingController>>
    ingredientControllers,
    TextEditingController canDoController,
    List<Map<String, dynamic>> originalIngredients,
  ) {
    return ElevatedButton(
      onPressed: () async {
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
              ),
        );

        try {
          String name = capitalizeFirstLetter(nameController.text.trim());
          String canDo = canDoController.text.trim();

          if (name.isEmpty ||
              canDo.isEmpty ||
              ingredientControllers.any(
                (pair) =>
                    pair.key.text.trim().isEmpty ||
                    pair.value.text.trim().isEmpty,
              )) {
            Navigator.pop(context); // Dismiss loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please fill in all fields')),
            );
            return;
          }

          try {
            int cando = int.tryParse(canDo.toString()) ?? 0;
            List<Map<String, dynamic>> ingredients =
                ingredientControllers.map((pair) {
                  return {
                    'name': capitalizeFirstLetter(pair.key.text.trim()),
                    'quantity': int.tryParse(pair.value.text.trim()) ?? 0,
                  };
                }).toList();

            // For editing, only check stock for new ingredients
            List<Map<String, dynamic>> ingredientsToCheck = [];
            
            if (item == null) {
              // If adding new item, check all ingredients
              ingredientsToCheck = ingredients;
            } else {
              // If editing, only check newly added ingredients
              ingredientsToCheck = _getNewIngredients(ingredients, originalIngredients);
            }

            List<String> missingOrLowStockMessages =
                await _checkStockAvailability(ingredientsToCheck);

            // Dismiss loading dialog before showing stock insufficient dialog
            Navigator.pop(context); // Dismiss loading dialog

            if (missingOrLowStockMessages.isNotEmpty) {
              await _showStockInsufficientDialog(
                missingOrLowStockMessages,
                context,
              );
              return;
            }

            // Now close the modal bottom sheet since everything is valid
            Navigator.pop(context);

            await _saveFinishedGood(item, name, ingredients, cando, originalIngredients);
          } catch (e) {
            Navigator.pop(context); // Dismiss loading dialog
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
          }
        } catch (e) {
          Navigator.pop(context); // Dismiss loading dialog
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save data: $e')));
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

  // Helper method to get only new ingredients that weren't in the original list
  List<Map<String, dynamic>> _getNewIngredients(
    List<Map<String, dynamic>> currentIngredients,
    List<Map<String, dynamic>> originalIngredients,
  ) {
    List<Map<String, dynamic>> newIngredients = [];
    
    for (var current in currentIngredients) {
      bool isNew = true;
      
      for (var original in originalIngredients) {
        if (current['name'].toLowerCase() == original['name'].toLowerCase()) {
          isNew = false;
          break;
        }
      }
      
      if (isNew) {
        newIngredients.add(current);
      }
    }
    
    return newIngredients;
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
    List<Map<String, dynamic>> ingredients,
    int canDo,
    List<Map<String, dynamic>> originalIngredients,
  ) async {
    final docRef = finishedGoodsRef.doc(name);
    if (item != null) {
      await docRef.update({
        'ingredients': ingredients,
        'canDo': canDo,
      });
    } else {
      await docRef.set({
        'name': name,
        'ingredients': ingredients,
        'canDo': canDo,
      });
    }

    // Determine which ingredients to deduct stock from
    List<Map<String, dynamic>> ingredientsToDeduct = [];
    
    if (item == null) {
      // If adding new item, deduct all ingredients
      ingredientsToDeduct = ingredients;
    } else {
      // If editing, only deduct newly added ingredients
      ingredientsToDeduct = _getNewIngredients(ingredients, originalIngredients);
    }

    // Deduct stock only for the determined ingredients
    for (var ing in ingredientsToDeduct) {
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
                color: const Color(0xFF4b8673),
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
              return widget.isAdmin 
              ? Slidable(
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
              ) : _buildFinishedGoodCard(item);
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
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Colors.grey.shade50,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
      border: Border.all(
        color: Colors.grey.shade200,
        width: 0.5,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B8673).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.document_normal,
                  color: Color(0xFF4B8673),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B8673),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Can do: ${item['canDo']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Compact ingredients section
          if (item['ingredients'] != null && item['ingredients'] is List)
            _buildCompactIngredients(item['ingredients'] as List<dynamic>),
        ],
      ),
    ),
  );
}

Widget _buildCompactIngredients(List<dynamic> ingredients) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Minimal section header
      Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF4B8673),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Ingredient${ingredients.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 8),
      
      // 2-column grid layout for ingredients
      _buildIngredientsGrid(ingredients),
    ],
  );
}

Widget _buildIngredientsGrid(List<dynamic> ingredients) {
  return Column(
    children: [
      // Create rows of 2 ingredients each
      for (int i = 0; i < ingredients.length; i += 2)
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < ingredients.length ? 6 : 0),
          child: Row(
            children: [
              // First ingredient in the row
              Expanded(
                child: _buildCompactIngredientChip(
                  ingredients[i]['name']?.toString() ?? '',
                  ingredients[i]['quantity']?.toString() ?? '0',
                ),
              ),
              // Second ingredient if exists
              if (i + 1 < ingredients.length) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactIngredientChip(
                    ingredients[i + 1]['name']?.toString() ?? '',
                    ingredients[i + 1]['quantity']?.toString() ?? '0',
                  ),
                ),
              ] else
                const Expanded(child: SizedBox()), // Empty space if odd number
            ],
          ),
        ),
    ],
  );
}

Widget _buildCompactIngredientChip(String name, String quantity) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.grey.shade300,
        width: 0.5,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF4B8673).withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            quantity,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B8673),
            ),
          ),
        ),
      ],
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