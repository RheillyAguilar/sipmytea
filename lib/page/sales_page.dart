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
    try {
      await FirebaseFirestore.instance
          .collection('daily_sales')
          .doc(formattedDate)
          .collection(widget.username)
          .doc(docIds[index])
          .delete();

      setState(() {
        salesData.removeAt(index);
        docIds.removeAt(index);
        totalSales = salesData.fold(
          0.0,
          (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0),
        );
      });
    } catch (e) {
      debugPrint("Error deleting sale: $e");
    }
  }

  // Add this function to your _SalesPageState class
  Future<void> addToInventorySales() async {
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

    int sum = 0;

    // Process the sales data
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dynamic amount = data['amount'] ?? 0.0;
      int amountInt = (amount is num) ? amount.toInt() : 0;

      final name = (data['productName'] ?? '').toString().toLowerCase();
      final productName = data['productName'] ?? 'Unknown';
      final size = (data['size'] ?? '').toString().toLowerCase();
      final category = data['category'] ?? 'Unknown';

      sum += amountInt;

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
    final Map<String, dynamic> existingData =
        existingDoc.exists
            ? Map<String, dynamic>.from(
              existingDoc.data() as Map<dynamic, dynamic>,
            )
            : {};

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

    // Prepare data to update
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
    final category = item['category'] ?? '';
    final productName = item['productName'] ?? 'Unknown';
    final size = item['size'] ?? 'N/A';
    final addOns = List<String>.from(item['addOns'] ?? []);
    final amount = item['amount']?.toDouble() ?? 0.0;

    return Dismissible(
      key: Key(docIds[index]),
      direction: DismissDirection.horizontal,
      confirmDismiss:
          (direction) => _confirmDialog(
            title: 'Confirm Deletion',
            content: 'Are you sure you want to delete this sale?',
             onConfirm: () async {
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

    await addToInventorySales();

    // Dismiss loading dialog
    Navigator.of(context).pop();
  },
          ),
      background: swipeBackground(isLeft: true),
      secondaryBackground: swipeBackground(isLeft: false),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$category | $productName ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Size: $size'),
                  Text(
                    "₱${amount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              if (addOns.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  "Add-ons:",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                ...addOns.map(
                  (addOn) =>
                      Text("- $addOn", style: const TextStyle(fontSize: 15)),
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
      body: isLoading 
      ? Center(
        child: LoadingAnimationWidget.fallingDot(color: const Color(0xFF4b8673), size: 80),
      ) : Column(
        children: [
          Expanded(
            child:
                salesData.isEmpty
                    ? buildEmptyState()
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
