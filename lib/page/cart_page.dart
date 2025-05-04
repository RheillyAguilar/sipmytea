import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cart_data.dart';

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
  double get totalCartPrice {
    return cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

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
    final amountController = TextEditingController();
    return await showModalBottomSheet<double>(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
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
                controller: amountController,
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
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final enteredAmount = double.tryParse(
                        amountController.text,
                      );
                      if (enteredAmount == null) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid number.'),
                          ),
                        );
                      } else {
                        Navigator.pop(context, enteredAmount);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B8673),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide.none,
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
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
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

  Future<DocumentSnapshot?> _getExistingStockDoc(
    List<String> possibleNames,
  ) async {
    final firestore = FirebaseFirestore.instance;
    for (String name in possibleNames) {
      final doc = await firestore.collection('stock').doc(name).get();
      if (doc.exists) {
        return doc;
      }
    }
    return null; // none found
  }

  void _confirmOrder() async {
    if (cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cart is already empty.')));
      }
      return;
    }

    final paidAmount = await _showAmountBottomSheet();

    if (paidAmount != null) {
      final total = totalCartPrice;
      if (paidAmount < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entered amount is less than total price!'),
          ),
        );
        return;
      }

      final change = paidAmount - total;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text('Change: ₱${change.toStringAsFixed(2)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      );

      final now = DateTime.now();
      final formattedDate = '${_monthName(now.month)} ${now.day} ${now.year}';
      final firestore = FirebaseFirestore.instance;
      final basePath = 'daily_sales/$formattedDate/${widget.username}';

      for (final item in cartItems) {
        final autoId = firestore.collection('temp').doc().id;
        await firestore.doc('$basePath/$autoId').set({
          'productName': item.productName,
          'size': item.size,
          'addOns': item.addOns,
          'amount': item.totalPrice,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // ====== START: Stock Management ======

        // PATTIES MANAGEMENT
        final pattiesDoc =
            await firestore.collection('stock').doc('Patties').get();
        if (pattiesDoc.exists) {
          final product = item.productName.toLowerCase();
          final pattiesNeeded =
              (['regular beef', 'cheese beef'].any(product.contains))
                  ? 2
                  : product.contains('combo')
                  ? 1
                  : 0;
          int currentQty = int.tryParse(pattiesDoc['quantity'].toString()) ?? 0;
          int updatedQty = (currentQty - pattiesNeeded).clamp(0, currentQty);
          int limit = int.tryParse(pattiesDoc['limit'].toString()) ?? 0;

          if (pattiesNeeded > 0) {
            await pattiesDoc.reference.update({
              'quantity': updatedQty.toString(),
            });
          }

          if (updatedQty <= limit) {
            await _handleWarning('Patties', updatedQty);
          }
        }

        // CHEESE STICK MANAGEMENT
        final cheeseStickDoc =
            await firestore.collection('stock').doc('Cheese Stick').get();
        if (cheeseStickDoc.exists) {
          final product = item.productName.toLowerCase();
          final cheeseNeeded =
              product.contains('cheesestick')
                  ? 10
                  : product.contains('combo')
                  ? 7
                  : 0;
          int currentQty =
              int.tryParse(cheeseStickDoc['quantity'].toString()) ?? 0;
          int updatedQty = (currentQty - cheeseNeeded).clamp(0, currentQty);
          int limit =
              int.tryParse(cheeseStickDoc['limit'].toString()) ?? 0;

          if (cheeseNeeded > 0) {
            await cheeseStickDoc.reference.update({
              'quantity': updatedQty.toString(),
            });
          }

          if (updatedQty <= limit) {
            await _handleWarning('Cheese Stick', updatedQty);
          }
        }

        // FRIES MANAGEMENT
        final friesDoc = await firestore.collection('stock').doc('Fries').get();
        if (friesDoc.exists) {
          final product = item.productName.toLowerCase();
          final friesNeeded =
              product.contains('fries')
                  ? 170
                  : product.contains('combo')
                  ? 120
                  : 0;
          int currentQty = int.tryParse(friesDoc['quantity'].toString()) ?? 0;
          int updatedQty = (currentQty - friesNeeded).clamp(0, currentQty);
          int limit =
              int.tryParse(friesDoc['limit'].toString()) ?? 0;

          if (friesNeeded > 0) {
            await friesDoc.reference.update({
              'quantity': updatedQty.toString(),
            });
          }

          if (updatedQty <= limit) {
            await _handleWarning('Fries', updatedQty);
          }
        }

        // EGG MANAGEMENT
        final eggDoc = await _getExistingStockDoc(['Egg', 'Itlog']);
        if (eggDoc != null) {
          final product = item.productName.toLowerCase();
          final eggsNeeded =
              product.contains('egg')
                  ? 2
                  : product.contains('silog')
                  ? 1
                  : 0;
          int currentQty = int.tryParse(eggDoc['quantity'].toString()) ?? 0;
          int updatedQty = (currentQty - eggsNeeded).clamp(0, currentQty);
          int limit = int.tryParse(eggDoc['limit'].toString()) ?? 0;

          if (eggsNeeded > 0) {
            await eggDoc.reference.update({'quantity': updatedQty.toString()});
          }

          if (updatedQty <= limit) {
            await _handleWarning(eggDoc.id, updatedQty);
          }
        }

        // BANS MANAGEMENT
        final bansDoc = await firestore.collection('stock').doc('Bans').get();
        if (bansDoc.exists) {
          final product = item.productName.toLowerCase();
          final bansNeeded =
              ([
                    'regular beef',
                    'cheese beef',
                    'egg sandwich',
                  ].any(product.contains))
                  ? 2
                  : product.contains('combo')
                  ? 1
                  : 0;
          int currentQty = int.tryParse(bansDoc['quantity'].toString()) ?? 0;
          int updatedQty = (currentQty - bansNeeded).clamp(0, currentQty);
          int limit = int.tryParse(bansDoc['limit'].toString()) ?? 0;

          if (bansNeeded > 0) {
            await bansDoc.reference.update({'quantity': updatedQty.toString()});
          }

          if (updatedQty <= limit) {
            await _handleWarning('Bans', updatedQty);
          }
        }

        // CUPS AND STRAW MANAGEMENT
        final cupSize = item.size.toLowerCase();
        final cupDocName =
            {'regular': 'Regular Cups', 'large': 'Large Cups'}[cupSize];
        if (cupDocName != null) {
          // Cups Deduction
          final cupDoc =
              await firestore.collection('stock').doc(cupDocName).get();
          int currentQty = int.tryParse(cupDoc['quantity'].toString()) ?? 0;
          int updatedQty = (currentQty - 1).clamp(0, currentQty);
          int limit = int.tryParse(cupDoc['limit'].toString()) ?? 0;

          if (cupDoc.exists) {
            await firestore.collection('stock').doc(cupDocName).update({
              'quantity': updatedQty.toString(),
            });
          }

          if (updatedQty <= limit) {
            await _handleWarning(cupDocName, updatedQty);
          }

          // Straw Deduction
          final strawDoc =
              await firestore.collection('stock').doc('Straw').get();
          int currentStrawQty =
              int.tryParse(strawDoc['quantity'].toString()) ?? 0;
          int updatedStrawQty = (currentStrawQty - 1).clamp(0, currentStrawQty);
          int strawLimit =
              int.tryParse(strawDoc['limit'].toString()) ?? 0;

          if (strawDoc.exists) {
            await firestore.collection('stock').doc('Straw').update({
              'quantity': updatedStrawQty.toString(),
            });
          }

          if (updatedStrawQty <= strawLimit) {
            await _handleWarning('Straw', updatedStrawQty);
          }
        }
      }

      // ====== END: Stock Management ======

      if (mounted) {
        setState(() {
          sales.addAll(
            cartItems.map(
              (item) => SaleItem(item: item, dateTime: DateTime.now()),
            ),
          );
          cartItems.clear();
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order confirmed!')));

        widget.onOrderConfirmed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return Dismissible(
                    key: Key(item.hashCode.toString()),
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      setState(() {
                        cartItems.removeAt(index);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Removed from cart")),
                      );
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name: ${item.productName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Size: ${item.size}',
                              style: const TextStyle(fontSize: 15),
                            ),
                            if (item.addOns.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                "Add-ons:",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              ...item.addOns.map(
                                (addOn) => Text(
                                  "- $addOn",
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "₱${item.totalPrice.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱${totalCartPrice.toStringAsFixed(2)}',
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
                      onPressed: _confirmOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B8673),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Order',
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
            ),
          ],
        ),
      ),
    );
  }
}
