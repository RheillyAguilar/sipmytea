// ignore_for_file: empty_statements

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SalesPage extends StatefulWidget {
  final String username;
  const SalesPage({super.key, required this.username});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  double totalSales = 0.0;
  List<Map<String, dynamic>> salesData = [];
  List<String> docIds = [];
  bool isLoading = true;

  String get formattedDateDisplay =>
      DateFormat('MMMM d, yyyy').format(DateTime.parse(today));
  String get formattedDate =>
      DateFormat('MMMM d yyyy').format(DateTime.parse(today));

  @override
  void initState() {
    super.initState();
    fetchSalesData();
  }

  Future<void> fetchSalesData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('daily_sales')
              .doc(formattedDate)
              .collection(widget.username)
              .get();

      final data = snapshot.docs.map((doc) => doc.data()).toList();
      final ids = snapshot.docs.map((doc) => doc.id).toList();

      setState(() {
        salesData = data;
        docIds = ids;
        totalSales = data.fold(
          0.0,
          (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0),
        );
      });
    } catch (e) {
      debugPrint("Error fetching sales: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(today) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        today = DateFormat('yyyy-MM-dd').format(picked);
      });
      await fetchSalesData();
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(content),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4b8673),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> deleteSale(int index) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
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
      await FirebaseFirestore.instance
          .collection('daily_sales')
          .doc(formattedDate)
          .collection(widget.username)
          .doc(docIds[index])
          .delete();

      setState(() {
        // Calculate the amount to subtract from total sales
        final amount = salesData[index]['amount']?.toDouble() ?? 0.0;
        
        // Remove the item from lists
        salesData.removeAt(index);
        docIds.removeAt(index);
        
        // Update total sales
        totalSales -= amount;
      });
    } catch (e) {
      debugPrint("Error deleting sale: $e");
    } finally {
      // Dismiss loading dialog
      Navigator.of(context).pop();
    }
  }

Future<void> addToInventorySales() async {
  setState(() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
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
  });

  try {
    final userSalesRef = FirebaseFirestore.instance
        .collection('daily_sales')
        .doc(formattedDate)
        .collection(widget.username);
    final snapshot = await userSalesRef.get();

    final inventoryDocRef = FirebaseFirestore.instance
        .collection('inventory')
        .doc('sales')
        .collection('daily_sales')
        .doc(widget.username);

    final existingDoc = await inventoryDocRef.get();

    // Process new sales into temporary lists
    List<Map<String, dynamic>> silogItems = [];
    List<Map<String, dynamic>> snackItems = [];
    List<Map<String, dynamic>> regularCupItems = [];
    List<Map<String, dynamic>> largeCupItems = [];

    // Payment method tracking
    Map<String, double> paymentMethodTotals = {};

    int sum = 0;

    // Process the sales data
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dynamic amount = data['amount'] ?? 0.0;
      int amountInt = (amount is num) ? amount.toInt() : 0;
      double amountDouble = (amount is num) ? amount.toDouble() : 0.0;

      final name = (data['productName'] ?? '').toString().toLowerCase();
      final productName = data['productName'] ?? 'Unknown';
      final size = (data['size'] ?? '').toString().toLowerCase();
      final category = data['category'] ?? 'Unknown';
      final paymentMethod = (data['paymentMethod'] ?? 'Unknown').toString();

      sum += amountInt;

      // Track payment method totals
      paymentMethodTotals[paymentMethod] = 
          (paymentMethodTotals[paymentMethod] ?? 0.0) + amountDouble;

      Map<String, dynamic> itemData = {
        'name': productName,
        'category': category,
      };

      // Add items to lists - allowing duplicates
      if (name.contains('silog'))
        silogItems.add(itemData);
      else if (RegExp(r'beef|cheese|egg|stick|fries|combo').hasMatch(name))
        snackItems.add(itemData);

      if (size == 'regular') {
        regularCupItems.add(itemData);
      } else if (size == 'large') {
        largeCupItems.add(itemData);
      }
    }

    // Get existing data with proper type casting
    final Map<String, dynamic> existingData = existingDoc.exists
        ? Map<String, dynamic>.from(
            existingDoc.data() as Map<dynamic, dynamic>,
          )
        : {};

    // Process existing payment method data
    Map<String, double> existingPaymentTotals = {};
    if (existingData.containsKey('paymentMethodTotals')) {
      final existing = existingData['paymentMethodTotals'];
      if (existing is Map) {
        existing.forEach((key, value) {
          existingPaymentTotals[key.toString()] = 
              (value is num) ? value.toDouble() : 0.0;
        });
      }
    }

    // Merge payment method totals
    paymentMethodTotals.forEach((method, amount) {
      existingPaymentTotals[method] = 
          (existingPaymentTotals[method] ?? 0.0) + amount;
    });

    // Process counts and categories together
    Map<String, int> silogCounts = {};
    Map<String, String> silogCategories = {};
    _processItemsWithCategories(
      existingData,
      'silogCount',
      'silogCategories',
      silogItems,
      silogCounts,
      silogCategories,
    );

    Map<String, int> snackCounts = {};
    Map<String, String> snackCategories = {};
    _processItemsWithCategories(
      existingData,
      'snackCount',
      'snackCategories',
      snackItems,
      snackCounts,
      snackCategories,
    );

    Map<String, int> regularCupCounts = {};
    Map<String, String> regularCupCategories = {};
    _processItemsWithCategories(
      existingData,
      'regularCupCount',
      'regularCupCategories',
      regularCupItems,
      regularCupCounts,
      regularCupCategories,
    );

    Map<String, int> largeCupCounts = {};
    Map<String, String> largeCupCategories = {};
    _processItemsWithCategories(
      existingData,
      'largeCupCount',
      'largeCupCategories',
      largeCupItems,
      largeCupCounts,
      largeCupCategories,
    );

    // Prepare data to update (including payment method data)
    final data = {
      'totalSales': (existingData['totalSales'] ?? 0) + sum,
      'silogCount': silogCounts,
      'snackCount': snackCounts,
      'regularCupCount': regularCupCounts,
      'largeCupCount': largeCupCounts,
      'silogCategories': silogCategories,
      'snackCategories': snackCategories,
      'regularCupCategories': regularCupCategories,
      'largeCupCategories': largeCupCategories,
      'paymentMethodTotals': existingPaymentTotals, // Add payment method data
      'timestamp': FieldValue.serverTimestamp(),
      'date': today,
    };

    // Update or insert the data
    await (existingDoc.exists
        ? inventoryDocRef.update(data)
        : inventoryDocRef.set({...data, 'username': widget.username}));

    // Delete the processed sales data
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Fetch the updated sales data
    await fetchSalesData();
  } catch (e) {
    print('Error: $e');
  } finally {
    // Dismiss loading dialog
    Navigator.pop(context);
    setState(() {
      isLoading = false;
    });
  }
}
  // Add this helper method to your _SalesPageState class
  void _processItemsWithCategories(
    Map<String, dynamic> existingData,
    String countField,
    String categoryField,
    List<Map<String, dynamic>> newItems,
    Map<String, int> counts,
    Map<String, String> categories,
  ) {
    // Create a map to track items by their combined category and name
    Map<String, Map<String, dynamic>> uniqueItems = {};

    // First, load existing counts
    if (existingData.containsKey(countField)) {
      final existingCounts = existingData[countField];
      if (existingCounts is Map) {
        existingCounts.forEach((key, value) {
          if (value is num) {
            counts[key.toString()] = value.toInt();
          } else if (value is String) {
            counts[key.toString()] = int.tryParse(value) ?? 1;
          } else {
            counts[key.toString()] = 1;
          }
        });
      } else if (existingCounts is List) {
        for (var item in existingCounts) {
          String itemStr = item.toString();
          counts[itemStr] = (counts[itemStr] ?? 0) + 1;
        }
      }
    }

    // Load existing categories
    if (existingData.containsKey(categoryField)) {
      final existingCategories = existingData[categoryField];
      if (existingCategories is Map) {
        existingCategories.forEach((key, value) {
          categories[key.toString()] = value.toString();

          // Add to uniqueItems for tracking
          String name = key.toString();
          String category = value.toString();
          String uniqueKey = "$category|$name";

          uniqueItems[uniqueKey] = {
            'name': name,
            'category': category,
            'count': counts[name] ?? 0,
          };
        });
      }
    }

    // Process new items with category preservation
    for (var item in newItems) {
      String name = item['name'];
      String category = item['category'];
      String uniqueKey = "$category|$name";

      // Check if we already have this exact item (same name AND category)
      if (uniqueItems.containsKey(uniqueKey)) {
        // This is an exact match - same name and category
        uniqueItems[uniqueKey]?['count'] =
            (uniqueItems[uniqueKey]?['count'] as int) + 1;
      } else {
        // This is either a new item or a name collision with different category
        // Let's check if the name exists with a different category
        bool nameExists = false;
        String existingCategory = '';

        for (String key in uniqueItems.keys) {
          if (uniqueItems[key]?['name'] == name) {
            nameExists = true;
            existingCategory = uniqueItems[key]?['category'] as String;
            break;
          }
        }

        if (nameExists && existingCategory != category) {
          // We have a name collision but different categories
          // Modify the name to include the category to distinguish them
          String modifiedName = "$name ($category)";
          String modifiedKey = "$category|$modifiedName";

          uniqueItems[modifiedKey] = {
            'name': modifiedName,
            'category': category,
            'count': 1,
          };
        } else {
          // New item or matching name and category
          uniqueItems[uniqueKey] = {
            'name': name,
            'category': category,
            'count': 1,
          };
        }
      }
    }

    // Convert uniqueItems back to counts and categories maps
    counts.clear();
    categories.clear();

    uniqueItems.forEach((key, item) {
      String name = item['name'] as String;
      counts[name] = item['count'] as int;
      categories[name] = item['category'] as String;
    });
  }

  Widget buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.money, size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No sales yet.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

 Widget buildSaleItem(Map<String, dynamic> item, int index) {
  final category = (item['category'] ?? '').toString();
  final productName = item['productName'] ?? 'Unknown';
  final size = item['size'] ?? 'N/A';
  final addOns = List<String>.from(item['addOns'] ?? []);
  final amount = item['amount']?.toDouble() ?? 0.0;
  final paymentMethod = item['paymentMethod'] ?? 'N/A';

  // Don't show size if category is silog or snack
  final showSize = category.toLowerCase() != 'silog' && category.toLowerCase() != 'snack';

  // Get payment method color
  Color getPaymentColor() {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return const Color(0xFF2ECC71);
      case 'gcash':
        return const Color(0xFF3498DB);
      default:
        return const Color(0xFF95A5A6);
    }
  }

  return Dismissible(
    key: Key(docIds[index]),
    direction: DismissDirection.horizontal,
    confirmDismiss: (direction) => _confirmDialog(
      title: 'Confirm Deletion',
      content: 'Are you sure you want to delete this sale?',
      onConfirm: () => deleteSale(index),
    ),
    background: swipeBackground(isLeft: true),
    secondaryBackground: swipeBackground(isLeft: false),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment method with modern styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: getPaymentColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: getPaymentColor().withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                'Payment: $paymentMethod',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: getPaymentColor(),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Product info section
            showSize ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category and product name
                Text(
                  '$category | $productName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                    height: 1.3,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Size and amount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE9ECEF),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Size: $size',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                    ),
                    
                    // Modern price display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF27AE60),
                            const Color(0xFF2ECC71),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF27AE60).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        "₱${amount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ) : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category and product name (flexible to take available space)
                Expanded(
                  child: Text(
                    '$category | $productName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                      height: 1.3,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Modern price display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF27AE60),
                        const Color(0xFF2ECC71),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF27AE60).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    "₱${amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            // Add-ons section with modern styling
            if (addOns.isNotEmpty) ...[
              const SizedBox(height: 16),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFE082),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add-ons:",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...addOns.map(
                      (addOn) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          "- $addOn",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFEF6C00),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget swipeBackground({required bool isLeft}) {
    return Container(
      color: Colors.red,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: LoadingAnimationWidget.fallingDot(
                  color: const Color(0xFF4b8673),
                  size: 80,
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child:
                        salesData.isEmpty
                            ? buildEmptyState()
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: salesData.length,
                              itemBuilder:
                                  (context, index) =>
                                      buildSaleItem(salesData[index], index),
                            ),
                  ),
                  if (salesData.isNotEmpty) buildBottomSummary(),
                ],
              ),
    );
  }

  Widget buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sales:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₱${totalSales.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  () => _confirmDialog(
                    title: 'Confirm Action',
                    content: 'Add sales to inventory and reset data?',
                    onConfirm: addToInventorySales,
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add to Inventory',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}