// Optimized version of your cart deduction methods for faster processing

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:sipmytea/cart_data.dart';
import 'package:sipmytea/widget/cart_item.dart';

// Enum for payment methods
enum PaymentMethod { cash, gcash }

class CartPage extends StatefulWidget {
  final String username;
  final VoidCallback onOrderConfirmed;

  const CartPage({
    super.key,
    required this.username,
    required this.onOrderConfirmed,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _firestore = FirebaseFirestore.instance;
  bool isLoading = false;

  // Cache for frequently accessed documents
  final Map<String, DocumentSnapshot> _documentCache = {};

  // Batch operations for better performance
  WriteBatch? _batch;

 // UPDATED: Single method to handle all deductions with batch operations + promo info
  Future<void> _saveOrderAndDeductStockOptimized(PaymentMethod paymentMethod) async {
    final now = DateTime.now();
    final formattedDate = '${_monthName(now.month)} ${now.day} ${now.year}';
    final path = 'daily_sales/$formattedDate/${widget.username}';

    // Start batch operation
    _batch = _firestore.batch();

    // Collect all deduction operations
    final Map<String, int> totalDeductions = {};
    final Map<String, int> finishedGoodsDeductions = {};
    final List<String> warningsToShow = [];

    try {
      // Pre-fetch all stock documents to reduce database calls
      await _preloadStockDocuments();

      // Process all cart items and calculate total deductions
      for (final item in cartItems) {
        // UPDATED: Save order record with payment method AND promo information
        final id = _firestore.collection('temp').doc().id;
        
        // Create base order data
        final Map<String, dynamic> orderData = {
          'category': item.category,
          'productName': item.productName,
          'size': item.size,
          'addOns': item.addOns,
          'amount': item.totalPrice,
          'paymentMethod': paymentMethod.name,
          'timestamp': FieldValue.serverTimestamp(),
        };

        // UPDATED: Add promo information if available
        if (item.promoName != null) {
          orderData['promoName'] = item.promoName;
        }
        
        if (item.discountAmount != null) {
          orderData['discountAmount'] = item.discountAmount;
        }

        // UPDATED: Add original price if there was a discount
        if (item.originalPrice != null) {
          orderData['originalPrice'] = item.originalPrice;
        }

        // Save to Firebase
        _batch!.set(_firestore.doc('$path/$id'), orderData);

        // Accumulate all deductions for this item
        final itemDeductions = await _calculateAllDeductions(item);

        // Merge deductions
        for (final entry in itemDeductions['stock']!.entries) {
          totalDeductions[entry.key] =
              (totalDeductions[entry.key] ?? 0) + entry.value;
        }

        for (final entry in itemDeductions['finishedGoods']!.entries) {
          finishedGoodsDeductions[entry.key] =
              (finishedGoodsDeductions[entry.key] ?? 0) + entry.value;
        }
      }

      // Apply all deductions in batch
      await _applyStockDeductions(totalDeductions, warningsToShow);
      await _applyFinishedGoodsDeductions(
        finishedGoodsDeductions,
        warningsToShow,
      );

      // Commit all changes at once
      await _batch!.commit();
      _batch = null;

      // Show warnings after successful commit
      for (final warning in warningsToShow) {
        await _showWarningFromString(warning);
      }
    } catch (e) {
      // Rollback on error
      _batch = null;
      rethrow;
    }
  }

// OPTIMIZED: Pre-load frequently accessed documents
  Future<void> _preloadStockDocuments() async {
    final futures = <Future<DocumentSnapshot>>[];

    // Common stock items
    final commonStockItems = [
      'regular cups',
      'large cups',
      'straw',
      'fructose',
      'nata',
      'cheese stick',
      'fries',
      'egg',
      'patties',
      'buns',
      'repolyo',
      'slice cheese',
      'coffee jelly',
      'chocomalt',
      'oreo crumbs',
      'yakult',
      'fresh milk', // Added fresh milk to common stock items
    ];

    // Add flavor-specific items based on cart contents
    final flavorItems = <String>{};
    for (final item in cartItems) {
      flavorItems.addAll(_getFlavorItemsForProduct(item));
    }

    // Fetch all documents concurrently
    for (final itemName in [...commonStockItems, ...flavorItems]) {
      futures.add(_firestore.collection('stock').doc(itemName).get());
    }

    // Finished goods
    final finishedGoodsItems = [
      'Pearl',
      'Creampuff',
      'Salted cheese',
      'Base',
      'Fresh Tea',
    ];
    for (final itemName in finishedGoodsItems) {
      futures.add(_firestore.collection('finished_goods').doc(itemName).get());
    }

    final results = await Future.wait(futures);

    // Cache results
    for (final doc in results) {
      if (doc.exists) {
        _documentCache[doc.id] = doc;
      }
    }
  }
  // OPTIMIZED: Get all flavor items for a product
  Set<String> _getFlavorItemsForProduct(CartItem item) {
    final items = <String>{};
    final name = item.productName.toLowerCase();
    item.category.toLowerCase();

    // Add flavor items based on product
    final flavorMaps = [
      {
        'chocolate': 'chocolate',
        'strawberry': 'strawberry',
        'blueberry': 'blueberry',
      },
      {
        'lychee': 'lychee',
        'wintermelon': 'wintermelon',
        'kiwi yakult': 'kiwi yakult',
      },
      {'honeydew': 'honeydew', 'taro': 'taro', 'matcha': 'matcha'},
      {
        'okinawa': 'okinawa',
        'dark chocolate': 'dark chocolate',
        'coffee': 'coffee',
      },
    ];

    for (final flavorMap in flavorMaps) {
      for (final entry in flavorMap.entries) {
        if (name.contains(entry.key)) {
          items.add(entry.value);
        }
      }
    }

    return items;
  }

  // OPTIMIZED: Calculate all deductions for a single item
  Future<Map<String, Map<String, int>>> _calculateAllDeductions(
    CartItem item,
  ) async {
    final stockDeductions = <String, int>{};
    final finishedGoodsDeductions = <String, int>{};

    final name = item.productName.toLowerCase();
    final category = item.category.toLowerCase();
    final size = item.size.toLowerCase();
    final validSize = size != "n/a";

    // Basic item deductions
    if (name.contains('cheesestick')) stockDeductions['cheese stick'] = 10;
    if (name.contains('fries')) stockDeductions['fries'] = 150;
    if (name.contains('silog')) stockDeductions['egg'] = 1;

    // Size-based deductions
    if (validSize) {
      stockDeductions.addAll(_getSmoothieDeductions(category, name, size));
      stockDeductions.addAll(_getFreshTeaDeduction(category, name, size));
      stockDeductions.addAll(_getCreampuffDeduction(category, name, size));
      stockDeductions.addAll(_getClassicDeduction(category, name, size));

      // Cup and straw
      final cupType = size == 'regular' ? 'regular cups' : 'large cups';
      stockDeductions[cupType] = (stockDeductions[cupType] ?? 0) + 1;
      stockDeductions['straw'] = (stockDeductions['straw'] ?? 0) + 1;
    }

    // Add-ons
    stockDeductions.addAll(_deductAddons(item.addOns));

    // Sugar level
    stockDeductions.addAll(_deductSugarlevel(item.sugarLevel));

    // Burger items
    stockDeductions.addAll(_deductBurger(name));

    // Finished goods calculations
    finishedGoodsDeductions.addAll(_calculateFinishedGoodsDeductions(item));

    return {'stock': stockDeductions, 'finishedGoods': finishedGoodsDeductions};
  }

  // OPTIMIZED: Calculate finished goods deductions
  Map<String, int> _calculateFinishedGoodsDeductions(CartItem item) {
    final deductions = <String, int>{};
    final category = item.category.toLowerCase();
    final name = item.productName.toLowerCase();
    final size = item.size.toLowerCase();
    final addOns = item.addOns.map((e) => e.toLowerCase()).toList();

    // Pearl deduction
    if (size != 'n/a') {
      deductions['Pearl'] = 1;
    }

    // Creampuff deduction
    int creampuffDeduction = 0;
    if (category == 'creampuff overload' && addOns.contains('creampuff')) {
      creampuffDeduction = 2;
    } else if (category == 'creampuff overload' ||
        addOns.contains('creampuff')) {
      creampuffDeduction = 1;
    }
    if (creampuffDeduction > 0) {
      deductions['Creampuff'] = creampuffDeduction;
    }

    // Salted cheese deduction
    int saltedDeduction = 0;
    if (category == 'smoothies' && addOns.contains('salted cheese')) {
      saltedDeduction = 2;
    } else if (category == 'smoothies' || addOns.contains('salted cheese')) {
      saltedDeduction = 1;
    }
    if (saltedDeduction > 0) {
      deductions['Salted cheese'] = saltedDeduction;
    }

    // Base deduction
    bool shouldDeductBase =
        category == 'classic milktea' ||
        (category == 'creampuff overload' &&
            (name.contains('dark chocolate') ||
                name.contains('cookies and cream') ||
                name.contains('matcha')));
    if (shouldDeductBase) {
      deductions['Base'] = 1;
    }

    // Fresh tea deduction
    if (category == 'fresh tea') {
      deductions['Fresh Tea'] = 1;
    }

    return deductions;
  }

  // OPTIMIZED: Apply stock deductions with batch operations
  Future<void> _applyStockDeductions(
    Map<String, int> deductions,
    List<String> warnings,
  ) async {
    for (final entry in deductions.entries) {
      final docName = entry.key;
      final deductionAmount = entry.value;

      final doc = _documentCache[docName];
      if (doc == null || !doc.exists) continue;

      final currentQty = int.tryParse(doc['quantity'].toString()) ?? 0;
      final limit = int.tryParse(doc['limit'].toString()) ?? 0;
      final updatedQty = (currentQty - deductionAmount).clamp(0, currentQty);

      _batch!.update(doc.reference, {'quantity': updatedQty});

      if (updatedQty <= limit) {
        warnings.add('$docName:$updatedQty');
      }
    }
  }

  // OPTIMIZED: Apply finished goods deductions with batch operations
  Future<void> _applyFinishedGoodsDeductions(
    Map<String, int> deductions,
    List<String> warnings,
  ) async {
    for (final entry in deductions.entries) {
      final docName = entry.key;
      final deductionAmount = entry.value;

      // Handle Pearl special case (fallback to nata)
      if (docName == 'Pearl') {
        await _handlePearlDeduction(deductionAmount, warnings);
        continue;
      }

      final doc = _documentCache[docName];
      if (doc == null || !doc.exists) continue;

      final currentCanDo = int.tryParse(doc['canDo'].toString()) ?? 0;
      final updatedCanDo = (currentCanDo - deductionAmount).clamp(
        0,
        currentCanDo,
      );

      if (updatedCanDo == 0) {
        _batch!.delete(doc.reference);
      } else {
        _batch!.update(doc.reference, {'canDo': updatedCanDo});
      }

      if (updatedCanDo <= 5 && updatedCanDo > 0) {
        warnings.add('$docName (canDo):$updatedCanDo');
      }
    }
  }

  // Handle Pearl deduction with nata fallback
  Future<void> _handlePearlDeduction(
    int totalDeduction,
    List<String> warnings,
  ) async {
    final pearlDoc = _documentCache['Pearl'];

    if (pearlDoc != null && pearlDoc.exists) {
      final currentCanDo = int.tryParse(pearlDoc['canDo'].toString()) ?? 0;
      final updatedCanDo = (currentCanDo - totalDeduction).clamp(
        0,
        currentCanDo,
      );

      if (updatedCanDo == 0) {
        _batch!.delete(pearlDoc.reference);
      } else {
        _batch!.update(pearlDoc.reference, {'canDo': updatedCanDo});
      }

      if (updatedCanDo <= 5 && updatedCanDo > 0) {
        warnings.add('Pearl (canDo):$updatedCanDo');
      }
    } else {
      // Fallback to nata
      final nataDoc = _documentCache['nata'];
      if (nataDoc != null && nataDoc.exists) {
        final currentQty = int.tryParse(nataDoc['quantity'].toString()) ?? 0;
        final limit = int.tryParse(nataDoc['limit'].toString()) ?? 0;
        final updatedQty = (currentQty - totalDeduction).clamp(0, currentQty);

        _batch!.update(nataDoc.reference, {'quantity': updatedQty});

        if (updatedQty <= limit) {
          warnings.add('Nata stock:$updatedQty');
        }
      }
    }
  }

  // Show warning from string format
  Future<void> _showWarningFromString(String warningString) async {
    final parts = warningString.split(':');
    if (parts.length == 2) {
      await _handleWarning(parts[0], int.parse(parts[1]));
    }
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
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
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Payment Dialog
  // ENHANCED: Payment method selection dialog
  Future<PaymentMethod?> _showPaymentMethodDialog() async {
    return showDialog<PaymentMethod>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B8673).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payment,
                    size: 48,
                    color: Color(0xFF4B8673),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: ₱${totalCartPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Payment options
                Column(
                  children: [
                    // Cash option
                    _buildPaymentOption(
                      icon: Icons.money,
                      title: 'Cash',
                      subtitle: 'Pay with physical cash',
                      color: Colors.green,
                      onTap:
                          () => Navigator.of(context).pop(PaymentMethod.cash),
                    ),
                    const SizedBox(height: 12),
                    // GCash option
                    _buildPaymentOption(
                      icon: Icons.phone_android,
                      title: 'Gcash',
                      subtitle: 'Pay with digital wallet',
                      color: Colors.blue,
                      onTap:
                          () => Navigator.of(context).pop(PaymentMethod.gcash),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ENHANCED: Handle payment based on method
  Future<double?> _handlePayment(PaymentMethod paymentMethod) async {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return await _showAmountBottomSheet();
      case PaymentMethod.gcash:
        return await _handleGCashPayment();
    }
  }

  // Handle GCash payment
  Future<double?> _handleGCashPayment() async {
    // Show GCash confirmation dialog
    final confirmed = await _showGCashConfirmationDialog();
    if (confirmed == true) {
      return totalCartPrice; // Return exact amount for GCash
    }
    return null;
  }

  Future<bool?> _showGCashConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    size: 48,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Gcash Payment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Amount: ₱${totalCartPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please confirm that the Gcash payment has been received.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4b8673),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ENHANCED: Main confirm order method with payment selection
  Future<void> _confirmOrderOptimized() async {
    if (cartItems.isEmpty) {
      _showSnackBar('Cart is already empty.');
      return;
    }

    // Step 1: Select payment method
    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return; // User cancelled

    // Step 2: Handle payment based on selected method
    final paid = await _handlePayment(paymentMethod);
    if (paid == null) return; // User cancelled payment

    // Step 3: Validate payment amount (only for cash)
    if (paymentMethod == PaymentMethod.cash && paid < totalCartPrice) {
      _showSnackBar('Entered amount is less than total price!');
      return;
    }

    setState(() => isLoading = true);

    // Show loading dialog
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
      // Step 4: Show change dialog (only for cash)
      if (paymentMethod == PaymentMethod.cash) {
        final change = paid - totalCartPrice;
        await _showChangeDialog(change);
      }

      // Step 5: Save order with payment method and deduct stock
      await _saveOrderAndDeductStockOptimized(paymentMethod);

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog

        setState(() {
          // Add payment method to sales items
          sales.addAll(
            cartItems.map((e) => SaleItem(
              item: e, 
              dateTime: DateTime.now(),
              paymentMethod: paymentMethod, // Add payment method to sales
            )),
          );
          cartItems.clear();
          isLoading = false;
        });
        widget.onOrderConfirmed();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        setState(() => isLoading = false);
        _showSnackBar('Error processing order: $e');
      }
    } finally {
      // Clear cache
      _documentCache.clear();
    }
  }

  // EXISTING HELPER METHODS (optimized where possible)

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Future<double?> _showAmountBottomSheet() async {
    final controller = TextEditingController();
    return showModalBottomSheet<double>(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter Amount Paid',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    hintText: 'Enter amount',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(controller.text);
                        Navigator.pop(context, amount);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B8673),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _handleWarning(String productName, int updatedQty) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
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
                ),
                const SizedBox(height: 24),
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
                  '$productName stock is low.\nOnly $updatedQty left.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 24),
                SizedBox(
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _showChangeDialog(double change) async {
    return showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text('Change: ₱${change.toStringAsFixed(2)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // OPTIMIZED HELPER METHODS FOR DEDUCTION CALCULATIONS

  Map<String, int> _deductBurger(String name) {
    final Map<String, int> result = {};
    if (name.contains('regular beef')) {
      result.addAll({'patties': 2, 'buns': 2, 'repolyo': 1});
    } else if (name.contains('cheese beef')) {
      result.addAll({'patties': 2, 'buns': 2, 'repolyo': 1, 'slice cheese': 2});
    } else if (name.contains('egg sandwich')) {
      result.addAll({'buns': 2, 'egg': 2, 'repolyo': 1});
    } else if (name.contains('combo')) {
      result.addAll({
        'buns': 1,
        'repolyo': 1,
        'slice cheese': 1,
        'patties': 1,
        'cheese stick': 7,
        'fries': 50,
      });
    }
    return result;
  }

  Map<String, int> _deductSugarlevel(String? sugarLevel) {
    final result = <String, int>{};
    if (sugarLevel == null || sugarLevel.isEmpty) return result;

    final level = sugarLevel.toLowerCase();
    if (level.contains('25%')) {
      result['fructose'] = 10;
    } else if (level.contains('50%')) {
      result['fructose'] = 20;
    } else if (level.contains('75%')) {
      result['fructose'] = 30;
    } else if (level.contains('100%')) {
      result['fructose'] = 40;
    }
    return result;
  }

  Map<String, int> _deductAddons(List<String> addOns) {
    final result = <String, int>{};
    for (final addon in addOns) {
      final lowerAddon = addon.toLowerCase();
      if (lowerAddon.contains('coffee jelly')) {
        result['coffee jelly'] = (result['coffee jelly'] ?? 0) + 2;
      } else if (lowerAddon.contains('chocomalt')) {
        result['chocomalt'] = (result['chocomalt'] ?? 0) + 15;
      } else if (lowerAddon.contains('oreo crumbs')) {
        result['oreo crumbs'] = (result['oreo crumbs'] ?? 0) + 15;
      } else if (lowerAddon.contains('yakult')) {
        result['yakult'] = (result['yakult'] ?? 0) + 1;
      } else if (lowerAddon.contains('vegetable')) {
        result['repolyo'] = (result['repolyo'] ?? 0) + 1;
      } else if (lowerAddon.contains('egg')) {
        result['egg'] = (result['egg'] ?? 0) + 1;
      } else if (lowerAddon.contains('slice cheese')) {
        result['slice cheese'] = (result['slice cheese'] ?? 0) + 1;
      }
    }
    return result;
  }

Map<String, int> _getSmoothieDeductions(
    String category,
    String name,
    String size,
  ) {
    if (category != 'smoothies') return {};

    final result = <String, int>{};
    
    // Add fresh milk deduction for all smoothies
    if (size == 'regular') {
      result['fresh milk'] = 50;
    } else if (size == 'large') {
      result['fresh milk'] = 100;
    }

    // Add flavor-specific deductions
    final smoothieMap = {
      'chocolate': 'chocolate',
      'strawberry': 'strawberry',
      'blueberry': 'blueberry',
      'mixberries': 'mixberries',
      'coffee': 'coffee',
      'mocha': 'mocha',
      'dark chocolate': 'dark chocolate',
    };

    for (final entry in smoothieMap.entries) {
      if (name.contains(entry.key)) {
        result[entry.value] = size == 'regular' ? 40 : 50;
        break;
      }
    }
    
    return result;
  }

  Map<String, int> _getFreshTeaDeduction(
    String category,
    String name,
    String size,
  ) {
    if (category != 'fresh tea') return {};

    final freshTeaMap = {
      'lychee': 'lychee',
      'wintermelon': 'wintermelon',
      'blueberry': 'blueberry',
      'strawberry': 'strawberry',
      'kiwi yakult': 'kiwi yakult',
    };

    for (final entry in freshTeaMap.entries) {
      if (name.contains(entry.key)) {
        return {entry.value: size == 'regular' ? 40 : 50};
      }
    }
    return {};
  }

   Map<String, int> _getCreampuffDeduction(
    String category,
    String name,
    String size,
  ) {
    if (category != 'creampuff overload') return {};

    final result = <String, int>{};
    
    // Check for specific items that need fresh milk deduction
    final freshMilkItems = ['taro', 'honeydew', 'matcha', 'dark chocolate'];
    final needsFreshMilk = freshMilkItems.any((item) => name.toLowerCase().contains(item));
    
    if (needsFreshMilk) {
      // These items only come in large size (100ml fresh milk)
      result['fresh milk'] = 100;
    }

    // Add flavor-specific deductions
    final creampuffOverloadMap = {
      'honeydew': 'honeydew',
      'taro': 'taro',
      'matcha': 'matcha',
      'dark chocolate': 'dark chocolate',
      'chocolate': 'chocolate',
      'cookies and cream': 'oreo crumbs',
      'chocomalt': 'chocomalt',
    };

    for (final entry in creampuffOverloadMap.entries) {
      if (name.contains(entry.key)) {
        result[entry.value] = 20;
        break;
      }
    }
    
    return result;
  }

  Map<String, int> _getClassicDeduction(
    String category,
    String name,
    String size,
  ) {
    if (category != 'classic milktea') return {};

    final highDeduct = {
      'wintermelon': 'wintermelon',
      'blueberry': 'blueberry',
      'strawberry': 'strawberry',
      'lychee': 'lychee',
      'yogurt': 'yogurt',
      'brown sugar': 'brown sugar',
    };

    final lowDeduct = {
      'okinawa': 'okinawa',
      'taro': 'taro',
      'honeydew': 'honeydew',
      'chocolate': 'chocolate',
      'coffee': 'coffee',
      'dark chocolate': 'dark chocolate',
    };

    for (final entry in highDeduct.entries) {
      if (name.contains(entry.key)) {
        return {entry.value: size == 'regular' ? 30 : 40};
      }
    }

    for (final entry in lowDeduct.entries) {
      if (name.contains(entry.key)) {
        return {entry.value: size == 'regular' ? 15 : 20};
      }
    }
    return {};
  }

  // PROPERTIES AND BUILD METHODS

  double get totalCartPrice =>
      cartItems.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [Expanded(child: _buildCartList()), _buildCartFooter()],
        ),
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final item = cartItems[index];
        return Dismissible(
          key: Key(item.hashCode.toString()),
          background: _buildDismissibleBg(Alignment.centerLeft),
          secondaryBackground: _buildDismissibleBg(Alignment.centerRight),
          onDismissed: (_) {
            setState(() => cartItems.removeAt(index));
            _showSnackBar('Removed from cart');
          },
          child: _buildCartItemCard(item),
        );
      },
    );
  }

  Widget _buildDismissibleBg(Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.red,
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

Widget _buildCartItemCard(CartItem item) {
  // Cache commonly used values
  final category = item.category.toLowerCase();
  final hasPromo = item.promoName != null && item.discountAmount != null;
  final showSizeAndSugar = category != 'snack' && category != 'silog';
  
  return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Product Icon/Avatar
                _buildProductIcon(category),
                const SizedBox(width: 16),
                
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Badge only
                      _buildCategoryBadge(item.category),
                      const SizedBox(height: 8),
                      
                      // Product Name
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                          height: 1.2,
                        ),
                      ),
                      
                      // Size and Sugar Level (conditional)
                      if (showSizeAndSugar) ...[
                        const SizedBox(height: 6),
                        _buildInfoChipsRow(item),
                      ],
                    ],
                  ),
                ),
                
                // Price Section
                _buildPriceSection(item, hasPromo),
              ],
            ),
            
            // Promo Section (conditional)
            if (item.promoName != null) ...[
              const SizedBox(height: 16),
              _buildPromoSection(item.promoName!, item.discountAmount!.toDouble()),
            ],
            
            // Add-ons Section (conditional)
            if (item.addOns.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildAddOnsSection(item.addOns),
            ],
          ],
        ),
      ),
    ),
  );
}

// Optimized helper methods
Widget _buildProductIcon(String category) {
  return Container(
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
  );
}

Widget _buildCategoryBadge(String category) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF4B8673).withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      category.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4B8673),
        letterSpacing: 0.5,
      ),
    ),
  );
}

Widget _buildPromoSection(String promoName, double? discountAmount) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green.shade200, width: 1),
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
  );
}



Widget _buildInfoChipsRow(CartItem item) {
  return Row(
    children: [
      _buildInfoChip(
        icon: Icons.local_drink_outlined,
        label: item.size,
        color: Colors.blue,
      ),
      const SizedBox(width: 8),
      _buildInfoChip(
        icon: Icons.water_drop_outlined,
        label: item.sugarLevel ?? '50%',
        color: Colors.orange,
      ),
    ],
  );
}


Widget _buildPriceSection(CartItem item, bool hasPromo) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // Original price with strikethrough (only if there's a discount)
      if (hasPromo && item.originalPrice != null) ...[
        Text(
          "₱${item.originalPrice!.toDouble().toStringAsFixed(2)}", // Fix: Convert to double
          style: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 2),
      ],
      
      // Current price container
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  ? Colors.red.shade400 
                  : const Color(0xFF4B8673)).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          "₱${item.totalPrice.toDouble().toStringAsFixed(2)}", // Fix: Convert to double
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    ],
  );
}

Widget _buildAddOnsSection(List<String> addOns) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_circle_outline, size: 16, color: Colors.grey.shade600),
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
          children: addOns.map((addon) => _buildAddOnChip(addon)).toList(),
        ),
      ],
    ),
  );
}

Widget _buildAddOnChip(String addon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300, width: 1),
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
}

// Helper widget for info chips (reused)
Widget _buildInfoChip({
  required IconData icon,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.2), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// Helper method to get product icons (reused)
IconData _getProductIcon(String category) {
  switch (category) {
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


  Widget _buildCartFooter() {
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
                'Total:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₱${totalCartPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  isLoading
                      ? null
                      : _confirmOrderOptimized, // Use optimized method
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Confirm Order',
                        style: TextStyle(color: Colors.white),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _documentCache.clear();
    super.dispose();
  }
}
