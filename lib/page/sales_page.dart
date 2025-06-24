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
    
    // Promo tracking - NEW
    Map<String, double> promoTotals = {};
    Map<String, int> promoCounts = {};
    double totalDiscountAmount = 0.0;

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
      
      // Promo data - NEW
      final promoName = data['promoName']?.toString();
      final discountAmount = data['discountAmount']?.toDouble();
      final originalPrice = data['originalPrice']?.toDouble();

      sum += amountInt;

      // Track payment method totals
      paymentMethodTotals[paymentMethod] = 
          (paymentMethodTotals[paymentMethod] ?? 0.0) + amountDouble;

      // Track promo data - NEW
      if (promoName != null && promoName.isNotEmpty && discountAmount != null && discountAmount > 0) {
        promoTotals[promoName] = (promoTotals[promoName] ?? 0.0) + discountAmount;
        promoCounts[promoName] = (promoCounts[promoName] ?? 0) + 1;
        totalDiscountAmount += discountAmount;
      }

      Map<String, dynamic> itemData = {
        'name': productName,
        'category': category,
        // Add promo information to item data - NEW
        if (promoName != null && promoName.isNotEmpty) 'promoName': promoName,
        if (discountAmount != null && discountAmount > 0) 'discountAmount': discountAmount,
        if (originalPrice != null) 'originalPrice': originalPrice,
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

    // Process existing promo data - NEW
    Map<String, double> existingPromoTotals = {};
    Map<String, int> existingPromoCounts = {};
    double existingTotalDiscountAmount = 0.0;

    if (existingData.containsKey('promoTotals')) {
      final existing = existingData['promoTotals'];
      if (existing is Map) {
        existing.forEach((key, value) {
          existingPromoTotals[key.toString()] = 
              (value is num) ? value.toDouble() : 0.0;
        });
      }
    }

    if (existingData.containsKey('promoCounts')) {
      final existing = existingData['promoCounts'];
      if (existing is Map) {
        existing.forEach((key, value) {
          existingPromoCounts[key.toString()] = 
              (value is num) ? value.toInt() : 0;
        });
      }
    }

    if (existingData.containsKey('totalDiscountAmount')) {
      existingTotalDiscountAmount = 
          (existingData['totalDiscountAmount'] is num) 
              ? (existingData['totalDiscountAmount'] as num).toDouble() 
              : 0.0;
    }

    // Merge promo data - NEW
    promoTotals.forEach((promo, amount) {
      existingPromoTotals[promo] = 
          (existingPromoTotals[promo] ?? 0.0) + amount;
    });

    promoCounts.forEach((promo, count) {
      existingPromoCounts[promo] = 
          (existingPromoCounts[promo] ?? 0) + count;
    });

    existingTotalDiscountAmount += totalDiscountAmount;

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

    // Prepare data to update (including payment method and promo data)
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
      'paymentMethodTotals': existingPaymentTotals,
      // Add promo data - NEW
      'promoTotals': existingPromoTotals,
      'promoCounts': existingPromoCounts,
      'totalDiscountAmount': existingTotalDiscountAmount,
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

// Add this helper method to your _SalesPageState class
IconData _getProductIcon(String category) {
  switch (category.toLowerCase()) {
    case 'classic milktea':
      return Icons.local_cafe;
    case 'fresh tea':
      return Icons.local_drink;
    case 'smoothies':
      return Icons.local_bar;
    case 'creampuff overload':
      return Icons.cake;
    case 'snack':
      return Icons.fastfood;
    case 'silog':
      return Icons.restaurant;
    default:
      return Icons.shopping_bag;
  }
}


Widget buildSaleItem(Map<String, dynamic> item, int index) {
  final category = (item['category'] ?? '').toString();
  final productName = item['productName'] ?? 'Unknown';
  final size = item['size'] ?? 'N/A';
  final addOns = List<String>.from(item['addOns'] ?? []);
  final amount = item['amount']?.toDouble() ?? 0.0;
  final paymentMethod = item['paymentMethod'] ?? 'N/A';
  
  // Promo related fields
  final promoName = item['promoName']?.toString();
  final discountAmount = item['discountAmount']?.toDouble();
  final originalPrice = item['originalPrice']?.toDouble();
  final hasPromo = promoName != null && promoName.isNotEmpty && discountAmount != null && discountAmount > 0;
  
  // Capitalize the first letter of payment method
  final capitalizedPaymentMethod = paymentMethod.isNotEmpty 
      ? paymentMethod[0].toUpperCase() + paymentMethod.substring(1).toLowerCase()
      : paymentMethod;

  // Don't show size if category is silog or snack
  final showSizeAndPayment = category.toLowerCase() != 'silog' && category.toLowerCase() != 'snack';

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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Product Icon/Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF4B8673).withOpacity(0.1),
                          const Color(0xFF4B8673).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4B8673).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getProductIcon(category),
                      color: const Color(0xFF4B8673),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B8673).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4B8673),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Product Name
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                            height: 1.2,
                          ),
                        ),
                        
                        // Size and Payment Method
                        if (showSizeAndPayment) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildInfoChip(
                                icon: Icons.local_drink_outlined,
                                label: size,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                icon: paymentMethod.toLowerCase() == 'cash' 
                                    ? Icons.payments_outlined 
                                    : Icons.account_balance_wallet_outlined,
                                label: capitalizedPaymentMethod,
                                color: getPaymentColor(),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Show only payment method for silog and snack
                          const SizedBox(height: 6),
                          _buildInfoChip(
                            icon: paymentMethod.toLowerCase() == 'cash' 
                                ? Icons.payments_outlined 
                                : Icons.account_balance_wallet_outlined,
                            label: capitalizedPaymentMethod,
                            color: getPaymentColor(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Price Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Show original price if there's a promo
                      if (hasPromo && originalPrice != null) ...[
                        Text(
                          "₱${originalPrice.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      
                      // Final amount
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                           gradient: LinearGradient(
            colors: hasPromo 
                ? [Colors.red.shade400, Colors.red.shade600] // Red for discounted
                : [const Color(0xFF4B8673), const Color(0xFF5A9B85)], // Green for regular
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (hasPromo 
                                  ? const Color(0xFFE74C3C) 
                                  : const Color(0xFF4B8673)).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "₱${amount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Promo Section (if applicable)
              if (hasPromo) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2ECC71).withOpacity(0.1),
                        const Color(0xFF27AE60).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2ECC71).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_offer, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(
              "Promo Applied:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.green.shade700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300, width: 1),
          ),
          child: Text(
            discountAmount != null 
                ? "$promoName - ₱${discountAmount.toStringAsFixed(2)}"
                : promoName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
                ),
              ],
              
              // Add-ons Section
              if (addOns.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Add-ons",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: addOns.map((addon) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              addon,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

// Helper method for info chips (you'll need to add this if it doesn't exist)
Widget _buildInfoChip({
  required IconData icon,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

// Corrected method to show options menu
void _showOptionsMenu() {
  final hasData = salesData.isNotEmpty; // Check if there's sales data
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          if (hasData) ...[
            _buildMenuOption(
              icon: Icons.inventory_outlined,
              title: 'Add to Inventory',
              subtitle: 'Transfer sales data to inventory records',
              onTap: () {
                Navigator.pop(context);
                _confirmDialog(
                  title: 'Add to Inventory',
                  content: 'This will move all sales data to inventory. Continue?',
                  onConfirm: addToInventorySales,
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          _buildMenuOption(
            icon: Icons.calendar_today_outlined,
            title: 'Change Date',
            subtitle: 'Select a different date to view',
            onTap: () {
              Navigator.pop(context);
              _pickDate();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4B8673).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4B8673),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
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

  // Build the header card similar to Monthly page
  Widget buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4B8673),
            Color(0xFF5A9B85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B8673).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.chart,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDateDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Daily Sales Report',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Total Sales',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₱${totalSales.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        title: const Text(
          'Sales',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF2C3E50),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.more, color: Color(0xFF4B8673)),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: LoadingAnimationWidget.fallingDot(
                color: const Color(0xFF4B8673),
                size: 80,
              ),
            )
          : Column(
              children: [
                buildHeaderCard(),
                Expanded(
                  child: salesData.isEmpty
                      ? buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: salesData.length,
                          itemBuilder: (context, index) {
                            return buildSaleItem(salesData[index], index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}