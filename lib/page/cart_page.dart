import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sipmytea/widget/cart_item.dart';
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
  final _firestore = FirebaseFirestore.instance;

  double get totalCartPrice =>
      cartItems.fold(0, (sum, item) => sum + item.totalPrice);

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

  Future<void> _deductStockAndAlert({
    required String docName,
    required int usedQty,
    required int limit,
  }) async {
    final doc = await _firestore.collection('stock').doc(docName).get();
    if (!doc.exists) return;

    int currentQty = int.tryParse(doc['quantity'].toString()) ?? 0;
    int updatedQty = (currentQty - usedQty).clamp(0, currentQty);

    await doc.reference.update({'quantity': updatedQty});
    if (updatedQty <= limit) {
      await _handleWarning(docName, updatedQty);
    }
  }

  Future<void> _confirmOrder() async {
    if (cartItems.isEmpty) {
      _showSnackBar('Cart is already empty.');
      return;
    }

    final paid = await _showAmountBottomSheet();
    if (paid == null || paid < totalCartPrice) {
      _showSnackBar('Entered amount is less than total price!');
      return;
    }

    final change = paid - totalCartPrice;
    await _showChangeDialog(change);

    await _saveOrderAndDeductStock();

    if (mounted) {
      setState(() {
        sales.addAll(
          cartItems.map((e) => SaleItem(item: e, dateTime: DateTime.now())),
        );
        cartItems.clear();
      });
      _showSnackBar('Order confirmed!');
      widget.onOrderConfirmed();
    }
  }

  Future<void> _saveOrderAndDeductStock() async {
    final now = DateTime.now();
    final formattedDate = '${_monthName(now.month)} ${now.day} ${now.year}';
    final path = 'daily_sales/$formattedDate/${widget.username}';

    for (final item in cartItems) {
      final id = _firestore.collection('temp').doc().id;
      await _firestore.doc('$path/$id').set({
        'productName': item.productName,
        'size': item.size,
        'addOns': item.addOns,
        'amount': item.totalPrice,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _handleInventory(item);
      await _deductCreampuffCanDo(item, item.addOns);
      await _deductSaltedCanDo(item.addOns);
    }
          await _deductPearlCanDo();

  }

Future<void> _deductSaltedCanDo(List<String> addOns) async {
  final docRef = _firestore.collection('finished_goods').doc('Salted Cheese');
  final saltedDoc = await docRef.get();
  if(!saltedDoc.exists) return;

  final rawCando = saltedDoc['canDo'];
  final currentCando = int.tryParse(rawCando.toString());
  if(currentCando == null) return;

  final updatedCando = (currentCando - 1).clamp(0, currentCando);

  await docRef.update({'canDo': updatedCando});

  if (updatedCando == 0) docRef.delete();
  if (updatedCando <= 5) _handleWarning('Salted Cheese (canDo)', updatedCando);

}


Future<void> _deductCreampuffCanDo(CartItem item, List<String> addOns) async {
  final category = item.category.toLowerCase();
  final hasCreampuff = addOns.map((e) => e.toLowerCase()).toList();

  int deduction = 0;
  if(category == 'creampuff overload' && hasCreampuff.contains('creampuff')) {
    deduction = 2;
  } else if (category == 'creampuff overload' || hasCreampuff.contains('creampuff')) {
    deduction = 1;
  } else {
    return;
  }
  
  final docRef = _firestore.collection('finished_goods').doc('Creampuff');
  final creampuffDoc = await docRef.get();
  if(!creampuffDoc.exists) return;

  final rawCando = creampuffDoc['canDo'];
  final currentCando = int.tryParse(rawCando.toString());
  if(currentCando == null) return;

  final updatedCando = (currentCando - deduction).clamp(0, currentCando);

  await docRef.update({'canDo': updatedCando});

  if (updatedCando == 0) docRef.delete();
  if (updatedCando <= 5) _handleWarning('Creampuff (canDo)', updatedCando);

}

  
Future<void> _deductPearlCanDo() async {
  final docRef = _firestore.collection('finished_goods').doc('Pearl');
  final nataRef = _firestore.collection('stock').doc('nata');

  // Get the current document for Pearl
  final doc = await docRef.get();

  // If 'Pearl' does NOT exist, deduct from 'nata'
  if (!doc.exists) {
    final nataDoc = await nataRef.get();
    if (nataDoc.exists) {
      final nataData = nataDoc.data();
      final currentQuantity = nataData?['quantity'] ?? 0;

      if (currentQuantity > 0) {
        final updatedQuantity = currentQuantity - 1;
        await nataRef.update({'quantity': updatedQuantity});

        // Optional: show a warning if quantity reaches the limit
        if (updatedQuantity <= nataData?['limit']) {
          await _handleWarning('Nata stock', updatedQuantity);
        }
      }
    }
    return; // Exit early since Pearl doesn't exist
  }

  // If Pearl exists, continue deduction from 'canDo'
  final data = doc.data();
  final rawCanDo = data?['canDo'];
  if (rawCanDo == null) return;

  final currentCanDo = int.tryParse(rawCanDo.toString());
  if (currentCanDo == null) return;

  final deduction = cartItems.length;
  final updatedCanDo = (currentCanDo - deduction).clamp(0, currentCanDo);
  await docRef.update({'canDo': updatedCanDo});

  // if the cando reach 0 will automatic delete
  if (updatedCanDo == 0) await docRef.delete();
  // if the cando reach 5 will pop a warning 
  if (updatedCanDo <= 5) await _handleWarning('Pearl (canDo)', updatedCanDo);

}


  Future<void> _handleInventory(CartItem item) async {
    final name = item.productName.toLowerCase();
    final category = item.category.toLowerCase();
    final size = item.size.toLowerCase();

    final deductions = <String, int>{
      if (['regular beef', 'cheese beef'].any(name.contains)) 'patties': 2,
      if (name.contains('combo')) 'patties': 1,
      if (name.contains('cheesestick')) 'cheese stick': 10,
      if (name.contains('combo')) 'cheese stick': 7,
      if (name.contains('fries')) 'fries': 170,
      if (name.contains('combo')) 'fries': 120,
      if (name.contains('egg')) 'egg': 2,
      if (name.contains('silog')) 'egg': 1,
      if (['regular beef', 'cheese beef', 'egg sandwich'].any(name.contains))
        'buns': 2,
      if (name.contains('combo')) 'buns': 1,
      ..._getSmoothieDeductions(category, name, size),
      ..._getFreshTeaDeduction(category, name, size),
      ..._getCreampuffDeduction(category, name, size),
      ..._getClassicDeduction(category, name, size)
    };

    for (final entry in deductions.entries) {
      final doc = await _getExistingStockDoc([entry.key]);
      if (doc != null) {
        final limit = int.tryParse(doc['limit'].toString()) ?? 0;
        await _deductStockAndAlert(
          docName: doc.id,
          usedQty: entry.value,
          limit: limit,
        );
      }
    }

    // Handle cups
    final cupDocName = {'regular': 'regular cups', 'large': 'large cups'}[size];
    if (cupDocName != null) {
      final doc = await _firestore.collection('stock').doc(cupDocName).get();
      final limit = int.tryParse(doc['limit'].toString()) ?? 0;
      await _deductStockAndAlert(docName: cupDocName, usedQty: 1, limit: limit);
    }
    // Handle straw
    final strawDoc = await _firestore.collection('stock').doc('straw').get();
    if (strawDoc.exists) {
      final limit = int.tryParse(strawDoc['limit'].toString()) ?? 0;
      await _deductStockAndAlert(docName: 'straw', usedQty: 1, limit: limit);
    }
  }

  Map<String, int> _getSmoothieDeductions(
    String category,
    String name,
    String size,
  ) {
    final smoothieMap = {
      'chocolate': 'chocolate',
      'strawberry': 'strawberry',
      'blueberry': 'blueberry',
      'mixberries': 'mixberries',
      'coffee': 'coffee',
      'mocha': 'mocha',
    };
    // handle deduction each categories
    return {
      for (final entry in smoothieMap.entries)
        if (category == 'smoothies' && name.contains(entry.key))
          entry.value: size == 'regular' ? 40 : 50,
    };
  }

  Map<String, int> _getFreshTeaDeduction(
    String category,
    String name,
    String size,
  ) {
    final freshTeaMap = {
      'lychee': 'lychee',
      'wintermelon': 'wintermelon',
      'blueberry': 'blueberry',
      'strawberry': 'strawberry',
      'kiwi yakult': ' kiwi yakult',
    };
    // handle deduction each categories
    return {
      for (final entry in freshTeaMap.entries)
        if (category == 'fresh tea' && name.contains(entry.key))
          entry.value: size == 'regular' ? 40 : 50,
    };
  }

  Map<String, int> _getCreampuffDeduction(
    String category,
    String name,
    String size,
  ) {
    final creampuffOverloadMap = {
      'honeydew': 'honeydew',
      'taro': 'taro',
      'match': 'matcha',
      'dark chocolate': 'dark chocolate',
      'cookies and cream': 'cookies and cream',
      'chocomalt': 'chocomalt',
    };
    // handle deduction each categories
    return {
      for (final entry in creampuffOverloadMap.entries)
        if (category == 'creampuff overload' && name.contains(entry.key))
          entry.value: 20,
    };
  }

Map<String, int> _getClassicDeduction(
  String category,
  String name,
  String size
) {
  final highDeduct = {
    'wintermelon': 'wintermelon',
    'blueberry' : 'blueberry',
    'strawberry' : 'strawberry',
    'lychee' : 'lychee',
    'yogurt' : 'yogurt',
    'brown sugar' : 'brown sugar',
    'plain' : 'plain'
   };

  final lowDeduct = {
     'okinawa' : 'okinawa',
    'taro' : 'taro',
    'honeydew' : 'honeydew',
    'chocolate' : 'chocolate',
    'coffee' : 'coffee',
  };

  if (category == 'classic milktea') {
    // handle deduction for powder
    for (final entry in highDeduct.entries) {
      if (name.toLowerCase().contains(entry.key)) {
        return {entry.value: size == 'regular' ? 30 : 40};
      }
    }
    // handle deduction for syrup
    for (final entry in lowDeduct.entries) {
      if (name.toLowerCase().contains(entry.key)) {
        return {entry.value: size == 'regular' ? 15 : 20};
      }
    }
  }

  return {};
}


  Future<DocumentSnapshot?> _getExistingStockDoc(List<String> names) async {
    for (final name in names) {
      final doc = await _firestore.collection('stock').doc(name).get();
      if (doc.exists) return doc;
    }
    return null;
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category: ${item.category}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Name: ${item.productName}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  "₱${item.totalPrice.toStringAsFixed(2)}",
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                )
              ],
            ),
            const SizedBox(height: 4),
            Text('Size: ${item.size}'),
            if (item.addOns.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                "Add-ons:",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ...item.addOns.map((a) => Text('- $a')),
            ],
          ],
        ),
      ),
    );
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
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
