// ignore_for_file: curly_braces_in_flow_control_structures, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class InventoryPage extends StatefulWidget {
  final String username;

  const InventoryPage({super.key, required this.username});

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String today;

  int inventoryTotalSales = 0;
  int totalExpenses = 0;
  int silogCount = 0, snackCount = 0, regularCupCount = 0, largeCupCount = 0;
  int cashTotal = 0;
  int gcashTotal = 0;

  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true; // Add a loading state variable

  @override
  void initState() {
    super.initState();
    today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  void _clearSalesStats() {
    setState(() {
      silogCount = snackCount = regularCupCount = largeCupCount = 0;
      cashTotal = gcashTotal = 0;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true; // Set loading to true before fetching data
    });

    try {
      await Future.wait([_loadExpenses(), _loadInventorySales()]);
    } catch (e) {
      // Handle errors if needed
      _showErrorSnackBar('Failed to load data: $e');
    } finally {
      setState(() {
        isLoading = false; // Set loading to false when done
      });
    }
  }

  Future<void> _loadExpenses() async {
    final snapshot =
        await firestore
            .collection('inventory')
            .doc('expenses')
            .collection('daily_expenses')
            .doc(widget.username)
            .collection('expenses')
            .get();

    final loadedExpenses =
        snapshot.docs
            .map(
              (doc) => {
                'id': doc.id, // Add document ID for deletion
                'name': doc['name'] ?? '',
                'amount': int.tryParse(doc['amount'].toString()) ?? 0,
              },
            )
            .toList();
    setState(() {
      expenses = loadedExpenses;
      totalExpenses = loadedExpenses.fold(
        0,
        (sum, e) => sum + (e['amount'] as int),
      );
    });
  }

  Future<void> _deleteExpense(String expenseId, int amount) async {
    try {
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

      // Delete from Firestore
      await firestore
          .collection('inventory')
          .doc('expenses')
          .collection('daily_expenses')
          .doc(widget.username)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      // Update local state
      setState(() {
        expenses.removeWhere((expense) => expense['id'] == expenseId);
        totalExpenses -= amount;
      });

      Navigator.of(context).pop(); // Close loading dialog
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Failed to delete expense: $e');
    }
  }

  Future<void> _loadInventorySales() async {
    try {
      final doc =
          await firestore
              .collection('inventory')
              .doc('sales')
              .collection('daily_sales')
              .doc(widget.username)
              .get();
      if (!doc.exists || doc['date'] != today) {
        _clearSalesStats();
        setState(() {
          inventoryTotalSales = 0;
          cashTotal = 0;
          gcashTotal = 0;
        });
        return;
      }

      // Calculate total counts for each category
      int calculatedSilogCount = 0;
      int calculatedSnackCount = 0;
      int calculatedRegularCupCount = 0;
      int calculatedLargeCupCount = 0;

      // Process the different category counts
      if (doc.data()!.containsKey('silogCount')) {
        calculatedSilogCount = _calculateTotalItemCount(
          doc.data()!,
          'silogCount',
        );
      }
      if (doc.data()!.containsKey('snackCount')) {
        calculatedSnackCount = _calculateTotalItemCount(
          doc.data()!,
          'snackCount',
        );
      }

      if (doc.data()!.containsKey('regularCupCount')) {
        calculatedRegularCupCount = _calculateTotalItemCount(
          doc.data()!,
          'regularCupCount',
        );
      }

      if (doc.data()!.containsKey('largeCupCount')) {
        calculatedLargeCupCount = _calculateTotalItemCount(
          doc.data()!,
          'largeCupCount',
        );
      }

// Extract payment method totals
int calculatedCashTotal = 0;
int calculatedGcashTotal = 0;

if (doc.data()!.containsKey('paymentMethodTotals')) {
  final paymentTotals = doc.data()!['paymentMethodTotals'];
  if (paymentTotals is Map) {
    // Cast to Map<String, dynamic> to match the expected type
    final paymentTotalsMap = Map<String, dynamic>.from(paymentTotals);
    calculatedCashTotal = _extractIntValue(paymentTotalsMap, 'cash');
    calculatedGcashTotal = _extractIntValue(paymentTotalsMap, 'gcash');
  }
}

      setState(() {
        // Safely extract totalSales as an integer
        inventoryTotalSales = _extractIntValue(doc.data(), 'totalSales');
        // Set the calculated counts
        silogCount = calculatedSilogCount;
        snackCount = calculatedSnackCount;
        regularCupCount = calculatedRegularCupCount;
        largeCupCount = calculatedLargeCupCount;
        // Set payment method totals
        cashTotal = calculatedCashTotal;
        gcashTotal = calculatedGcashTotal;
      });
    } catch (e) {
      // Handle error gracefully, maybe show a message to user
      _clearSalesStats();
      setState(() {
        inventoryTotalSales = 0;
        cashTotal = 0;
        gcashTotal = 0;
      });
    }
  }

  // New helper method to calculate total item count for a category
  int _calculateTotalItemCount(Map<String, dynamic> data, String countKey) {
    var countData = data[countKey];
    int totalCount = 0;

    if (countData is List) {
      // If it's a list format, the count is the list length
      totalCount = countData.length;
    } else if (countData is Map) {
      // If it's a map format, sum up all the values
      countData.forEach((itemName, count) {
        if (count is int)
          totalCount += count;
        else if (count is String)
          totalCount += int.tryParse(count) ?? 1;
        // Default to 1 if we can't parse the count
        else
          totalCount += 1;
      });
      // If it's just a direct integer
    } else if (countData is int)
      totalCount = countData;
    // If it's a string that can be parsed as a number
    else if (countData is String)
      totalCount = int.tryParse(countData) ?? 0;

    return totalCount;
  }

  // Helper method to safely extract integer values from Firestore data
  int _extractIntValue(Map<String, dynamic>? data, String key) {
    if (data == null || !data.containsKey(key)) return 0;

    var value = data[key];
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0; // Default fallback
  }

Future<void> _addToDailySales() async {
  final netSales = inventoryTotalSales - totalExpenses;

  final inventoryDoc =
      await firestore
          .collection('inventory')
          .doc('sales')
          .collection('daily_sales')
          .doc(widget.username)
          .get();

  final docRef = firestore
      .collection('daily_records')
      .doc(today)
      .collection('users')
      .doc(widget.username);

  final currentDocSnap = await docRef.get();
  final currentData = currentDocSnap.data();
  final inventoryData = inventoryDoc.data() ?? {};

  // Initialize updatedData from currentData or as an empty map
  final updatedData = Map<String, dynamic>.from(currentData ?? {});

  // Update basic fields
  updatedData
    ..['totalSales'] = (currentData?['totalSales'] ?? 0) + inventoryTotalSales
    ..['silogCount'] = (currentData?['silogCount'] ?? 0) + silogCount
    ..['snackCount'] = (currentData?['snackCount'] ?? 0) + snackCount
    ..['regularCupCount'] =
        (currentData?['regularCupCount'] ?? 0) + regularCupCount
    ..['largeCupCount'] = (currentData?['largeCupCount'] ?? 0) + largeCupCount
    ..['netSales'] = (currentData?['netSales'] ?? 0) + netSales
    ..['timestamp'] = Timestamp.now()
    ..['username'] = widget.username
    ..['date'] = today;

  // Add payment method totals
  updatedData['cashTotal'] = (currentData?['cashTotal'] ?? 0) + cashTotal;
  updatedData['gcashTotal'] = (currentData?['gcashTotal'] ?? 0) + gcashTotal;

  // Merge expense lists
  final existingExpenses = currentData?['expenses'] ?? [];
  updatedData['expenses'] = [...existingExpenses, ...expenses];

  // Helper to merge category maps
  void _mergeCategory(String key) {
    if (inventoryData.containsKey(key)) {
      final existing = Map<String, dynamic>.from(currentData?[key] ?? {});
      existing.addAll(Map<String, dynamic>.from(inventoryData[key]));
      updatedData[key] = existing;
    }
  }

  // Merge all categories
  _mergeCategory('silogCategories');
  _mergeCategory('snackCategories');
  _mergeCategory('regularCupCategories');
  _mergeCategory('largeCupCategories');

  // Merge count and detailed items
  void _mergeCountAndItems(String countKey, String detailKey) {
    if (inventoryData.containsKey(countKey)) {
      _transferCountData(
        inventoryData,
        currentData,
        updatedData,
        countKey,
        detailKey,
      );
    }
  }

  _mergeCountAndItems('silogCount', 'silogDetailedItems');
  _mergeCountAndItems('snackCount', 'snackDetailedItems');
  _mergeCountAndItems('regularCupCount', 'regularCupDetailedItems');
  _mergeCountAndItems('largeCupCount', 'largeCupDetailedItems');

  // Save updated data
  if (currentData == null)
    await docRef.set(updatedData);
  else
    await docRef.update(updatedData);
}

  // Helper method to transfer count data
  void _transferCountData(
    Map<String, dynamic> sourceData,
    Map<String, dynamic>? currentData,
    Map<String, dynamic> updatedData,
    String countKey,
    String detailedItemsKey,
  ) {
    var countData = sourceData[countKey];
    Map<String, dynamic> detailedItems = {};

    if (countData is Map) {
      detailedItems = Map<String, dynamic>.from(countData);
    } else if (countData is List) {
      // Convert list format to map format with counts
      for (var item in countData) {
        if (item is String) {
          detailedItems[item] = (detailedItems[item] ?? 0) + 1;
        }
      }
    }

    if (detailedItems.isNotEmpty) {
      Map<String, dynamic> existingItems = Map<String, dynamic>.from(
        currentData?[detailedItemsKey] ?? {},
      );

      detailedItems.forEach((key, value) {
        int count = value is int ? value : int.tryParse(value.toString()) ?? 0;
        int existingCount =
            existingItems[key] is int
                ? existingItems[key]
                : int.tryParse(existingItems[key]?.toString() ?? '0') ?? 0;

        existingItems[key] = existingCount + count;
      });

      updatedData[detailedItemsKey] = existingItems;
    }
  }

  // Existing _clearFirestoreData function from your code
  Future<void> _clearFirestoreData() async {
    final batch = firestore.batch();

    // Delete sales
    final sales =
        await firestore
            .collection('daily_sales')
            .doc(today)
            .collection(widget.username)
            .get();
    for (var doc in sales.docs) {
      batch.delete(doc.reference);
    }

    // Delete expenses
    final expensesSnapshot =
        await firestore
            .collection('inventory')
            .doc('expenses')
            .collection('daily_expenses')
            .doc(widget.username)
            .collection('expenses')
            .get();
    for (var doc in expensesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete summary
    final summaryDoc = firestore
        .collection('inventory')
        .doc('sales')
        .collection('daily_sales')
        .doc(widget.username);
    batch.delete(summaryDoc);

    await batch.commit();
  }

  // Store context for loading dialog to safely dismiss it later
  BuildContext? _loadingDialogContext;

  // Complete _confirmDailySales function
  Future<void> _confirmDailySales() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 40,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Alert',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Are sure to add this to Daily Sales',
                  style: TextStyle(fontSize: 15),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  // Close confirm dialog
                  Navigator.of(dialogContext).pop();

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) {
                      _loadingDialogContext = loadingContext;
                      return Dialog(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: Center(
                          child: LoadingAnimationWidget.fallingDot(
                            color: Colors.white,
                            size: 80,
                          ),
                        ),
                      );
                    },
                  );

                  try {
                    await _addToDailySales();
                    await _clearFirestoreData();

                    // Close loading dialog safely
                    if (_loadingDialogContext != null && mounted) {
                      Navigator.of(_loadingDialogContext!).pop();
                      _loadingDialogContext = null;
                    }

                    if (mounted) {
                      setState(() {
                        _clearSalesStats();
                        expenses.clear();
                        totalExpenses = 0;
                        inventoryTotalSales = 0;
                      });
                    }
                  } catch (e) {
                    // Close loading dialog safely on error
                    if (_loadingDialogContext != null && mounted) {
                      Navigator.of(_loadingDialogContext!).pop();
                      _loadingDialogContext = null;
                    }

                    if (mounted) {
                      _showErrorSnackBar('Failed to process: $e');
                    }
                  }
                },

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
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(today) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        today = DateFormat('yyyy-MM-dd').format(picked);
        inventoryTotalSales = totalExpenses = 0;
        expenses.clear();
        _clearSalesStats();
      });
      await _loadData();
    }
  }

  // Helper function to capitalize the first letter of a string
  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _showExpenseModalSheet() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: _buildExpenseForm(nameController, amountController),
          ),
    );
  }

  Widget _buildExpenseForm(
    TextEditingController nameController,
    TextEditingController amountController,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Add Expense',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildTextField(controller: nameController, label: 'Expense Name'),
        const SizedBox(height: 12),
        _buildTextField(
          controller: amountController,
          label: 'Amount',
          isNumber: true,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () async {
                final rawName = nameController.text.trim();
                final name = capitalizeFirstLetter(
                  rawName,
                ); // Capitalize the first letter
                final amount = int.tryParse(amountController.text.trim()) ?? 0;

                if (name.isEmpty || amount <= 0) {
                  _showErrorSnackBar('Please enter valid expense details');
                  return;
                }

                final expenseData = {
                  'name': name,
                  'amount': amount,
                  'date': today,
                  'timestamp': Timestamp.now(),
                  'username': widget.username,
                };

                // Show loading indicator while processing
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
                Navigator.of(context).pop();

                try {
                  final docRef = await firestore
                      .collection('inventory')
                      .doc('expenses')
                      .collection('daily_expenses')
                      .doc(widget.username)
                      .collection('expenses')
                      .add(expenseData);

                  setState(() {
                    expenses.add({
                      'id': docRef.id, // Add the document ID
                      'name': name, 
                      'amount': amount
                    });
                    totalExpenses += amount;
                  });

                  Navigator.of(context).pop();
                } catch (_) {
                  Navigator.of(context).pop();
                  _showErrorSnackBar('Failed to save expense');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  TextField _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Widget _buildPaymentMethodCards() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Card(
                color: Colors.green[400],
                child: ListTile(
                  title: const Text(
                    'Cash',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '₱$cashTotal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  leading: const Icon(
                    Icons.money,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Card(
                color: Colors.blue[400],
                child: ListTile(
                  title: const Text(
                    'Gcash',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '₱$gcashTotal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  leading: const Icon(
                    Icons.phone_android,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = inventoryTotalSales > 0 || totalExpenses > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: isLoading
          ? Center(
            child: LoadingAnimationWidget.fallingDot(
              color: const Color(0xFF4b8673),
              size: 80,
            ),
          )
          : hasData 
              ? _buildScrollableContent() 
              : _buildEmptyState(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExpenseModalSheet,
        backgroundColor: const Color(0xFF4b8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: hasData ? _buildBottomBar() : null,
    );
  }

  Widget _buildScrollableContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (inventoryTotalSales > 0)
                  Card(
                    color: Colors.grey[100],
                    child: ListTile(
                      title: Text(
                        'Sales: ₱$inventoryTotalSales',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Add payment method cards here
                if (inventoryTotalSales > 0) _buildPaymentMethodCards(),
                
                const SizedBox(height: 20),
                if (inventoryTotalSales > 0) ...[
                  Row(
                    children: [
                      Expanded(child: _buildCategoryCard('Silog', Color(0xffb19985))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCategoryCard('Snacks', Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildCategoryCard('Large Cup',Color(0XFF944547),)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCategoryCard('Regular Cup', Color(0xff7b679a))),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                if (expenses.isNotEmpty) _buildExpenseCard(),
                const SizedBox(height: 100), // Extra space for bottom navigation
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No inventory yet.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, Color color) {
    int count = 0;

    // Determine the count based on the title
    switch (title) {
      case 'Silog':
        count = silogCount;
        break;
      case 'Snacks':
        count = snackCount;
        break;
      case 'Regular Cup':
        count = regularCupCount;
        break;
      case 'Large Cup':
        count = largeCupCount;
        break;
    }

    return GestureDetector(
      onTap: () => _showCategoryDialog(title, color),
      child: Card(
        color: color,
        child: ListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '$count sold',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _showCategoryDialog(String categoryTitle, Color cardColor) async {
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
      final DocumentSnapshot doc =
          await firestore
              .collection('inventory')
              .doc('sales')
              .collection('daily_sales')
              .doc(widget.username)
              .get();

      Navigator.pop(context); // Close the loading dialog

      if (!doc.exists) {
        _showErrorDialog('No data found for $categoryTitle.');
        return;
      }

      Map<String, Map<String, int>> subcategoryItems = {};
      String countFieldName = '';
      String categoriesFieldName = '';
      bool useSubcategories = true;

      switch (categoryTitle) {
        case 'Silog':
          countFieldName = 'silogCount';
          useSubcategories = false;
          break;
        case 'Snacks':
          countFieldName = 'snackCount';
          useSubcategories = false;
          break;
        case 'Regular Cup':
          countFieldName = 'regularCupCount';
          categoriesFieldName = 'regularCupCategories';
          break;
        case 'Large Cup':
          countFieldName = 'largeCupCount';
          categoriesFieldName = 'largeCupCategories';
          break;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Build subc

      // Build subcategory map
      Map<String, String> itemToSubcategory = {};
      if (useSubcategories &&
          categoriesFieldName.isNotEmpty &&
          data.containsKey(categoriesFieldName)) {
        var categories = data[categoriesFieldName];
        if (categories is Map) {
          categories.forEach((key, value) {
            if (key is String && value is String) {
              itemToSubcategory[key] = value;
            }
          });
        }
      }

      // Parse item counts
      if (data.containsKey(countFieldName)) {
        final countData = data[countFieldName];

        if (countData is List) {
          for (var item in countData) {
            if (item is String) {
              _incrementItemCount(
                item,
                useSubcategories,
                itemToSubcategory,
                subcategoryItems,
              );
            }
          }
        } else if (countData is Map) {
          countData.forEach((key, value) {
            if (key is String) {
              int count = 1;
              if (value is int) {
                count = value;
              } else if (value is String) {
                count = int.tryParse(value) ?? 1;
              }

              _addItemWithCount(
                key,
                count,
                useSubcategories,
                itemToSubcategory,
                subcategoryItems,
              );
            }
          });
        }
      }

      // Prepare badge colors
      Color badgeBackgroundColor = cardColor.withOpacity(0.3);
      Color badgeTextColor = cardColor.withOpacity(0.9);

      // Show the breakdown dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                '$categoryTitle Breakdown',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child:
                    subcategoryItems.isEmpty
                        ? const Center(
                          child: Text('No detailed data available.'),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: subcategoryItems.entries.fold(
                            0,
                            (sum, e) => sum! + e.value.length,
                          ),
                          itemBuilder: (context, index) {
                            int itemsFound = 0;
                            String? currentSubcategory;
                            MapEntry<String, int>? currentItem;

                            for (var entry in subcategoryItems.entries) {
                              final items = entry.value;
                              if (index < itemsFound + items.length) {
                                currentSubcategory = entry.key;
                                currentItem = items.entries.elementAt(
                                  index - itemsFound,
                                );
                                break;
                              }
                              itemsFound += items.length;
                            }

                            if (currentSubcategory == null ||
                                currentItem == null) {
                              return const SizedBox.shrink();
                            }

                            String displayName = _cleanItemName(
                              currentItem.key,
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                    horizontal: 16.0,
                                  ),
                                  child: Row(
                                    children: [
                                      if (currentSubcategory.isNotEmpty) ...[
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            currentSubcategory,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 24,
                                          color: Colors.grey.shade300,
                                        ),
                                      ],
                                      Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 16.0,
                                          ),
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 4.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeBackgroundColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          '${currentItem.value}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: badgeTextColor,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      Navigator.pop(context); // Ensure loading is dismissed
      _showErrorDialog('Failed to load data: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Helper method to clean item names by removing parentheses
  String _cleanItemName(String itemName) {
    // If the item name contains parentheses, take only the part before it
    int indexOfParenthesis = itemName.indexOf('(');
    if (indexOfParenthesis > 0) {
      return itemName.substring(0, indexOfParenthesis).trim();
    }
    return itemName;
  }

  // Helper method to increment item count in subcategoryItems map
  void _incrementItemCount(
    String item,
    bool useSubcategories,
    Map<String, String> itemToSubcategory,
    Map<String, Map<String, int>> subcategoryItems,
  ) {
    if (useSubcategories) {
      // Find the subcategory for this item
      String subcategory = itemToSubcategory[item] ?? "Other";

      // Initialize the subcategory map if needed
      if (!subcategoryItems.containsKey(subcategory)) {
        subcategoryItems[subcategory] = {};
      }

      // Increment the count for this item in its subcategory
      subcategoryItems[subcategory]![item] =
          (subcategoryItems[subcategory]![item] ?? 0) + 1;
    } else {
      // For Silog and Snacks, just use a blank subcategory
      if (!subcategoryItems.containsKey('')) {
        subcategoryItems[''] = {};
      }

      // Increment the count for this item
      subcategoryItems['']![item] = (subcategoryItems['']![item] ?? 0) + 1;
    }
  }

  // New helper method to add item with specific count
  void _addItemWithCount(
    String item,
    int count,
    bool useSubcategories,
    Map<String, String> itemToSubcategory,
    Map<String, Map<String, int>> subcategoryItems,
  ) {
    if (useSubcategories) {
      // Find the subcategory for this item
      String subcategory = itemToSubcategory[item] ?? "Other";

      // Initialize the subcategory map if needed
      if (!subcategoryItems.containsKey(subcategory)) {
        subcategoryItems[subcategory] = {};
      }

      // Set the count for this item in its subcategory
      subcategoryItems[subcategory]![item] = count;
    } else {
      // For Silog and Snacks, just use a blank subcategory
      if (!subcategoryItems.containsKey('')) {
        subcategoryItems[''] = {};
      }

      // Set the count for this item
      subcategoryItems['']![item] = count;
    }
  }

  Widget _buildExpenseCard() {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 10),
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expenses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...expenses.map(
            (expense) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                expense['name'],
                style: const TextStyle(fontSize: 15),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₱${expense['amount']}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 25),
                  GestureDetector(
                    onTap: () => _showDeleteExpenseDialog(
                      expense['id'],
                      expense['name'],
                      expense['amount'],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Text(
            'Total Expenses: ₱$totalExpenses',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

void _showDeleteExpenseDialog(String expenseId, String expenseName, int amount) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 40,
              ),
              SizedBox(width: 8),
              Text(
                'Delete Expense',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to delete "$expenseName" (₱$amount)?',
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop(); // Close confirm dialog
            await _deleteExpense(expenseId, amount);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
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
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

  Widget _buildBottomBar() {
    final netSales = (inventoryTotalSales - totalExpenses).toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Sales:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₱$netSales',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _confirmDailySales,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A705E),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Add to Daily Sales',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
