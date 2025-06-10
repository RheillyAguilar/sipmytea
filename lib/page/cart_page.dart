// Optimized version of your cart deduction methods for faster processing

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:sipmytea/cart_data.dart';
import 'package:sipmytea/widget/cart_item.dart';

class CartPage extends StatefulWidget {

  final String username;
  final VoidCallback onOrderConfirmed;

  const CartPage({
    super.key,
    required this.username,
    required this.onOrderConfirmed
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

  // OPTIMIZED: Single method to handle all deductions with batch operations
  Future<void> _saveOrderAndDeductStockOptimized() async {
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
        // Save order record
        final id = _firestore.collection('temp').doc().id;
        _batch!.set(_firestore.doc('$path/$id'), {
          'category': item.category,
          'productName': item.productName,
          'size': item.size,
          'addOns': item.addOns,
          'amount': item.totalPrice,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Accumulate all deductions for this item
        final itemDeductions = await _calculateAllDeductions(item);
        
        // Merge deductions
        for (final entry in itemDeductions['stock']!.entries) {
          totalDeductions[entry.key] = (totalDeductions[entry.key] ?? 0) + entry.value;
        }
        
        for (final entry in itemDeductions['finishedGoods']!.entries) {
          finishedGoodsDeductions[entry.key] = (finishedGoodsDeductions[entry.key] ?? 0) + entry.value;
        }
      }

      // Apply all deductions in batch
      await _applyStockDeductions(totalDeductions, warningsToShow);
      await _applyFinishedGoodsDeductions(finishedGoodsDeductions, warningsToShow);

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
      'regular cups', 'large cups', 'straw', 'fructose', 'nata',
      'cheese stick', 'fries', 'egg', 'patties', 'buns', 'repolyo',
      'slice cheese', 'coffee jelly', 'chocomalt', 'oreo crumbs', 'yakult'
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
    final finishedGoodsItems = ['Pearl', 'Creampuff', 'Salted cheese', 'Base', 'Fresh Tea'];
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
    final category = item.category.toLowerCase();
    
    // Add flavor items based on product
    final flavorMaps = [
      {'chocolate': 'chocolate', 'strawberry': 'strawberry', 'blueberry': 'blueberry'},
      {'lychee': 'lychee', 'wintermelon': 'wintermelon', 'kiwi yakult': 'kiwi yakult'},
      {'honeydew': 'honeydew', 'taro': 'taro', 'matcha': 'matcha'},
      {'okinawa': 'okinawa', 'dark chocolate': 'dark chocolate', 'coffee': 'coffee'}
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
  Future<Map<String, Map<String, int>>> _calculateAllDeductions(CartItem item) async {
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

    return {
      'stock': stockDeductions,
      'finishedGoods': finishedGoodsDeductions,
    };
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
    } else if (category == 'creampuff overload' || addOns.contains('creampuff')) {
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
    bool shouldDeductBase = category == 'classic milktea' ||
        (category == 'creampuff overload' && 
         (name.contains('dark chocolate') || name.contains('cookies and cream') || name.contains('matcha')));
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
  Future<void> _applyStockDeductions(Map<String, int> deductions, List<String> warnings) async {
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
  Future<void> _applyFinishedGoodsDeductions(Map<String, int> deductions, List<String> warnings) async {
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
      final updatedCanDo = (currentCanDo - deductionAmount).clamp(0, currentCanDo);
      
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
  Future<void> _handlePearlDeduction(int totalDeduction, List<String> warnings) async {
    final pearlDoc = _documentCache['Pearl'];
    
    if (pearlDoc != null && pearlDoc.exists) {
      final currentCanDo = int.tryParse(pearlDoc['canDo'].toString()) ?? 0;
      final updatedCanDo = (currentCanDo - totalDeduction).clamp(0, currentCanDo);
      
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

  // OPTIMIZED: Main confirm order method
  Future<void> _confirmOrderOptimized() async {
    if (cartItems.isEmpty) {
      _showSnackBar('Cart is already empty.');
      return;
    }

    final paid = await _showAmountBottomSheet();
    if (paid == null || paid < totalCartPrice) {
      _showSnackBar('Entered amount is less than total price!');
      return;
    }

    setState(() => isLoading = true);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: LoadingAnimationWidget.fallingDot(color: Colors.white, size: 80),
        ),
      ),
    );

    try {
      final change = paid - totalCartPrice;
      await _showChangeDialog(change);
      
      // Use optimized method
      await _saveOrderAndDeductStockOptimized();

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog

        setState(() {
          sales.addAll(
            cartItems.map((e) => SaleItem(item: e, dateTime: DateTime.now())),
          );
          cartItems.clear();
          isLoading = false;
        });

        _showSnackBar('Order confirmed!');
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
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
      builder: (context) => Padding(
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      builder: (_) => AlertDialog(
        title: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        'buns': 1, 'repolyo': 1, 'slice cheese': 1, 'patties': 1,
        'cheese stick': 7, 'fries': 50,
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

  Map<String, int> _getSmoothieDeductions(String category, String name, String size) {
    if (category != 'smoothies') return {};
    
    final smoothieMap = {
      'chocolate': 'chocolate', 'strawberry': 'strawberry', 'blueberry': 'blueberry',
      'mixberries': 'mixberries', 'coffee': 'coffee', 'mocha': 'mocha',
      'dark chocolate': 'dark chocolate'
    };

    for (final entry in smoothieMap.entries) {
      if (name.contains(entry.key)) {
        return {entry.value: size == 'regular' ? 40 : 50};
      }
    }
    return {};
  }

  Map<String, int> _getFreshTeaDeduction(String category, String name, String size) {
    if (category != 'fresh tea') return {};
    
    final freshTeaMap = {
      'lychee': 'lychee', 'wintermelon': 'wintermelon', 'blueberry': 'blueberry',
      'strawberry': 'strawberry', 'kiwi yakult': 'kiwi yakult',
    };

    for (final entry in freshTeaMap.entries) {
      if (name.contains(entry.key)) {
        return {entry.value: size == 'regular' ? 40 : 50};
      }
    }
    return {};
  }

  Map<String, int> _getCreampuffDeduction(String category, String name, String size) {
    if (category != 'creampuff overload') return {};
    
    final creampuffOverloadMap = {
      'honeydew': 'honeydew', 'taro': 'taro', 'matcha': 'matcha',
      'dark chocolate': 'dark chocolate', 'chocolate': 'chocolate',
      'cookies and cream': 'cookies and cream', 'chocomalt': 'chocomalt',
    };

    for (final entry in creampuffOverloadMap.entries) {
      if (name.contains(entry.key)) {
        return {entry.value: 20};
      }
    }
    return {};
  }

  Map<String, int> _getClassicDeduction(String category, String name, String size) {
    if (category != 'classic milktea') return {};
    
    final highDeduct = {
      'wintermelon': 'wintermelon', 'blueberry': 'blueberry', 'strawberry': 'strawberry',
      'lychee': 'lychee', 'yogurt': 'yogurt', 'brown sugar': 'brown sugar',
    };

    final lowDeduct = {
      'okinawa': 'okinawa', 'taro': 'taro', 'honeydew': 'honeydew',
      'chocolate': 'chocolate', 'coffee': 'coffee', 'dark chocolate': 'dark chocolate'
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

  double get totalCartPrice => cartItems.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCartList()),
            _buildCartFooter(),
          ],
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
    bool showSizeAndSugar = item.category.toLowerCase() != 'snack' && 
                          item.category.toLowerCase() != 'silog';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            showSizeAndSugar
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.category} | ${item.productName}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text("${item.size} - ${item.sugarLevel}"),
                        ],
                      ),
                      Text(
                        "₱${item.totalPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.category} | ${item.productName}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "₱${item.totalPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 4),
            if (item.addOns.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text("Add-ons:", style: TextStyle(fontWeight: FontWeight.w500)),
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
              const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              onPressed: isLoading ? null : _confirmOrderOptimized, // Use optimized method
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Confirm Order', style: TextStyle(color: Colors.white)),
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