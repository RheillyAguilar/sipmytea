// ignore_for_file: curly_braces_in_flow_control_structures, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
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

  int promoCount = 0;
  int promoTotal = 0;
  Map<String, dynamic> promoDetails = {};
  Map<String, dynamic> promoTotalDetails = {}; // ADD THIS NEW VARIABLE

  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;

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
    promoCount = 0;
    promoTotal = 0;
    promoDetails = {};
    promoTotalDetails = {};
  });
}



  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Future.wait([_loadExpenses(), _loadInventorySales()]);
    } catch (e) {
      _showErrorSnackBar('Failed to load data: $e');
    } finally {
      setState(() {
        isLoading = false;
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
                'id': doc.id,
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

      await firestore
          .collection('inventory')
          .doc('expenses')
          .collection('daily_expenses')
          .doc(widget.username)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      setState(() {
        expenses.removeWhere((expense) => expense['id'] == expenseId);
        totalExpenses -= amount;
      });

      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar('Failed to delete expense: $e');
    }
  }

  // Fixed _loadInventorySales method - replace the promo loading section

Future<void> _loadInventorySales() async {
  try {
    final doc = await firestore
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

    final docData = doc.data()!;

    // Calculate total counts for each category
    int calculatedSilogCount = _calculateTotalItemCount(docData, 'silogCount');
    int calculatedSnackCount = _calculateTotalItemCount(docData, 'snackCount');
    int calculatedRegularCupCount = _calculateTotalItemCount(docData, 'regularCupCount');
    int calculatedLargeCupCount = _calculateTotalItemCount(docData, 'largeCupCount');

    // Extract payment method totals
    int calculatedCashTotal = 0;
    int calculatedGcashTotal = 0;

    if (docData.containsKey('paymentMethodTotals')) {
      final paymentTotals = docData['paymentMethodTotals'];
      if (paymentTotals is Map) {
        final paymentTotalsMap = Map<String, dynamic>.from(paymentTotals);
        calculatedCashTotal = _extractIntValue(paymentTotalsMap, 'cash');
        calculatedGcashTotal = _extractIntValue(paymentTotalsMap, 'gcash');
      }
    }

    int calculatedPromoCount = 0;
    int calculatedPromoTotal = 0;
    Map<String, dynamic> calculatedPromoDetails = {};
    Map<String, dynamic> calculatedPromoTotalDetails = {};

    // FIXED: Load promo counts
    if (docData.containsKey('promoCounts')) {
      final promoCounts = docData['promoCounts'];
      print('Raw promoCounts from Firestore: $promoCounts');
      
      if (promoCounts is Map) {
        final promoCountsMap = Map<String, dynamic>.from(promoCounts);
        promoCountsMap.forEach((key, value) {
          int count = 0;
          if (value is int) {
            count = value;
          } else if (value is String) {
            count = int.tryParse(value) ?? 0;
          } else if (value is double) {
            count = value.toInt();
          }
          calculatedPromoCount += count;
          calculatedPromoDetails[key] = count;
        });
      }
    }

    // FIXED: Load promo totals - This was the main issue
    if (docData.containsKey('promoTotals')) {
      final promoTotals = docData['promoTotals'];
      print('Raw promoTotals from Firestore: $promoTotals');
      
      if (promoTotals is Map) {
        final promoTotalsMap = Map<String, dynamic>.from(promoTotals);
        promoTotalsMap.forEach((key, value) {
          int total = 0;
          if (value is int) {
            total = value;
          } else if (value is String) {
            total = int.tryParse(value) ?? 0;
          } else if (value is double) {
            total = value.toInt();
          }
          print('Processing promo total - Key: $key, Value: $value, Parsed: $total');
          calculatedPromoTotal += total;
          calculatedPromoTotalDetails[key] = total;
        });
      }
    }

    // ADDITIONAL FIX: Check if the data structure is different
    // Sometimes the data might be stored differently in Firestore
    if (calculatedPromoTotalDetails.isEmpty && docData.containsKey('promoData')) {
      final promoData = docData['promoData'];
      if (promoData is Map) {
        final promoDataMap = Map<String, dynamic>.from(promoData);
        promoDataMap.forEach((key, value) {
          if (value is Map) {
            final promoInfo = Map<String, dynamic>.from(value);
            if (promoInfo.containsKey('total')) {
              int total = _extractIntValue(promoInfo, 'total');
              calculatedPromoTotal += total;
              calculatedPromoTotalDetails[key] = total;
            }
          }
        });
      }
    }

    print('Final calculated promo details: $calculatedPromoDetails');
    print('Final calculated promo total details: $calculatedPromoTotalDetails');
    print('Final calculated promo total: $calculatedPromoTotal');

    setState(() {
      inventoryTotalSales = _extractIntValue(docData, 'totalSales');
      silogCount = calculatedSilogCount;
      snackCount = calculatedSnackCount;
      regularCupCount = calculatedRegularCupCount;
      largeCupCount = calculatedLargeCupCount;
      cashTotal = calculatedCashTotal;
      gcashTotal = calculatedGcashTotal;
      
      // SET THE PROMO VARIABLES INSIDE setState
      promoCount = calculatedPromoCount;
      promoTotal = calculatedPromoTotal;
      promoDetails = calculatedPromoDetails;
      promoTotalDetails = calculatedPromoTotalDetails;
    });
    
  } catch (e) {
    print('Error loading inventory sales: $e');
    _clearSalesStats();
    setState(() {
      inventoryTotalSales = 0;
      cashTotal = 0;
      gcashTotal = 0;
    });
  }
}
  int _calculateTotalItemCount(Map<String, dynamic> data, String countKey) {
    // First try the direct key
    var countData = data[countKey];
    int totalCount = 0;

    if (countData == null) {
      // Try alternative keys
      List<String> altKeys = [];
      switch (countKey) {
        case 'silogCount':
          altKeys = ['silog', 'silogs', 'silogItems'];
          break;
        case 'snackCount':
          altKeys = ['snack', 'snacks', 'snackItems'];
          break;
        case 'regularCupCount':
          altKeys = ['regular', 'regularCup', 'regularItems'];
          break;
        case 'largeCupCount':
          altKeys = ['large', 'largeCup', 'largeItems'];
          break;
      }

      for (String key in altKeys) {
        if (data.containsKey(key)) {
          countData = data[key];
          break;
        }
      }
    }

    if (countData == null) return 0;

    if (countData is List) {
      totalCount = countData.length;
    } else if (countData is Map) {
      countData.forEach((itemName, count) {
        if (count is int) {
          totalCount += count;
        } else if (count is String) {
          int parsedCount = int.tryParse(count) ?? 1;
          totalCount += parsedCount;
        } else {
          totalCount += 1;
        }
      });
    } else if (countData is int) {
      totalCount = countData;
    } else if (countData is String) {
      totalCount = int.tryParse(countData) ?? 0;
    }

    return totalCount;
  }

  int _extractIntValue(Map<String, dynamic>? data, String key) {
    if (data == null || !data.containsKey(key)) return 0;

    var value = data[key];
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
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

  final updatedData = Map<String, dynamic>.from(currentData ?? {});

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

  updatedData['cashTotal'] = (currentData?['cashTotal'] ?? 0) + cashTotal;
  updatedData['gcashTotal'] = (currentData?['gcashTotal'] ?? 0) + gcashTotal;

  // ADD PROMO DATA TO DAILY RECORDS
  if (promoCount > 0) {
    updatedData['promoCount'] = (currentData?['promoCount'] ?? 0) + promoCount;
    updatedData['promoTotal'] = (currentData?['promoTotal'] ?? 0) + promoTotal;
    
    // Merge promo details (counts)
    if (promoDetails.isNotEmpty) {
      Map<String, dynamic> existingPromoDetails = Map<String, dynamic>.from(
        currentData?['promoDetails'] ?? {},
      );
      
      promoDetails.forEach((promoName, count) {
        int existingCount = existingPromoDetails[promoName] is int 
            ? existingPromoDetails[promoName] 
            : int.tryParse(existingPromoDetails[promoName]?.toString() ?? '0') ?? 0;
        
        int newCount = count is int ? count : int.tryParse(count.toString()) ?? 0;
        existingPromoDetails[promoName] = existingCount + newCount;
      });
      
      updatedData['promoDetails'] = existingPromoDetails;
    }
    
    // Merge promo total details
    if (promoTotalDetails.isNotEmpty) {
      Map<String, dynamic> existingPromoTotalDetails = Map<String, dynamic>.from(
        currentData?['promoTotalDetails'] ?? {},
      );
      
      promoTotalDetails.forEach((promoName, total) {
        int existingTotal = existingPromoTotalDetails[promoName] is int 
            ? existingPromoTotalDetails[promoName] 
            : int.tryParse(existingPromoTotalDetails[promoName]?.toString() ?? '0') ?? 0;
        
        int newTotal = total is int ? total : int.tryParse(total.toString()) ?? 0;
        existingPromoTotalDetails[promoName] = existingTotal + newTotal;
      });
      
      updatedData['promoTotalDetails'] = existingPromoTotalDetails;
    }
  }

  final existingExpenses = currentData?['expenses'] ?? [];
  updatedData['expenses'] = [...existingExpenses, ...expenses];

  void _mergeCategory(String key) {
    if (inventoryData.containsKey(key)) {
      final existing = Map<String, dynamic>.from(currentData?[key] ?? {});
      existing.addAll(Map<String, dynamic>.from(inventoryData[key]));
      updatedData[key] = existing;
    }
  }

  _mergeCategory('silogCategories');
  _mergeCategory('snackCategories');
  _mergeCategory('regularCupCategories');
  _mergeCategory('largeCupCategories');

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

  if (currentData == null)
    await docRef.set(updatedData);
  else
    await docRef.update(updatedData);
}
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

  Future<void> _clearFirestoreData() async {
    final batch = firestore.batch();

    final sales =
        await firestore
            .collection('daily_sales')
            .doc(today)
            .collection(widget.username)
            .get();
    for (var doc in sales.docs) {
      batch.delete(doc.reference);
    }

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

    final summaryDoc = firestore
        .collection('inventory')
        .doc('sales')
        .collection('daily_sales')
        .doc(widget.username);
    batch.delete(summaryDoc);

    await batch.commit();
  }

  BuildContext? _loadingDialogContext;

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
                  Navigator.of(dialogContext).pop();

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
        _buildTextField(
          controller: nameController,
          label: 'Expense Name',
          icon: Icons.receipt_long,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: amountController,
          label: 'Amount',
          isNumber: true,
          icon: Icons.money,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () async {
                final rawName = nameController.text.trim();
                final name = capitalizeFirstLetter(rawName);
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
                      'id': docRef.id,
                      'name': name,
                      'amount': amount,
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
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            icon != null ? Icon(icon, color: const Color(0xFF4B8673)) : null,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
void _showPromoDetails() async {
  // Show loading dialog first
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
    Navigator.of(context).pop();

    // Show the actual promo details dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.local_offer, color: Colors.amber, size: 24),
              SizedBox(width: 12),
              Text(
                'Promo Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 300),
            child: promoDetails.isEmpty
                ? const Center(
                    child: Text(
                      'No promos applied',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : Column(
                    children: [
                      // Header row
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Promo Name',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Count',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content rows
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: promoDetails.entries.map((entry) {
                                String promoName = entry.key;
                                int promoCount = entry.value;
                                
                                // Fixed: Better handling of individual total
                                int individualTotal = 0;
                                if (promoTotalDetails.containsKey(promoName)) {
                                  var totalValue = promoTotalDetails[promoName];
                                  if (totalValue is int) {
                                    individualTotal = totalValue;
                                  } else if (totalValue is String) {
                                    individualTotal = int.tryParse(totalValue) ?? 0;
                                  } else if (totalValue is double) {
                                    individualTotal = totalValue.toInt();
                                  }
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.amber.withOpacity(0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          promoName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          promoCount.toString(),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '₱${individualTotal.toString()}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

  } catch (e) {
    // Close loading dialog if there's an error
    Navigator.of(context).pop();
    
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to load promo details: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Widget _buildPromoCard() {
    return GestureDetector(
      onTap: () => _showPromoDetails(),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.amber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Promo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$promoCount',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCards() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildPaymentMethodCard(
                'Cash',
                cashTotal,
                Iconsax.money,
                const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPaymentMethodCard(
                'GCash',
                gcashTotal,
                Iconsax.mobile,
                const Color(0xFF3B82F6),
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
        title: const Text(
          'Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C3E50)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.more, color: Color(0xFF4B8673)),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body:
          hasData
              ? isLoading
                  ? Center(
                    child: LoadingAnimationWidget.fallingDot(
                      color: const Color(0xFF4B8673),
                      size: 80,
                    ),
                  )
                  : Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildHeaderCard(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (inventoryTotalSales > 0) ...[
                                 _buildPromoCard(),
                                _buildPaymentMethodCards(),

                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCategoryCard(
                                        'Silog',
                                        const Color(0xFFB19985),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildCategoryCard(
                                        'Snacks',
                                        const Color(0xFFFF6B35),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildCategoryCard(
                                        'Large',
                                        const Color(0xFF944547),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildCategoryCard(
                                        'Regular',
                                        const Color(0xFF7B679A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                              // Only show expense card if totalExpenses > 0
                              if (totalExpenses > 0) _buildExpenseCard(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
              : _buildEmptyState(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExpenseModalSheet,
        backgroundColor: const Color(0xFF4b8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Add method to show options menu
  void _showOptionsMenu() {
    final hasData = inventoryTotalSales > 0 || totalExpenses > 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
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
                    icon: Icons.add_circle_outline,
                    title: 'Add to Daily Summary',
                    subtitle: 'Transfer inventory data to daily records',
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDailySales();
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
              child: Icon(icon, color: const Color(0xFF4B8673), size: 20),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // Build header card similar to Monthly Sales
  Widget _buildHeaderCard() {
    final netSales = inventoryTotalSales - totalExpenses;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B8673), Color(0xFF5A9B84)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B8673).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Iconsax.chart, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat(
                        'MMMM d, y',
                      ).format(DateTime.tryParse(today) ?? DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Daily Inventory Report',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Total Sales',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '₱${inventoryTotalSales.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (totalExpenses > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expenses',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '₱${totalExpenses.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Net Sales',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '₱${netSales.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: netSales >= 0 ? Colors.white : Colors.red[200],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
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

  Widget _buildPaymentMethodCard(
    String title,
    int amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),

      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${amount.toString()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, Color color) {
    int count = 0;

    switch (title) {
      case 'Silog':
        count = silogCount;
        break;
      case 'Snacks':
        count = snackCount;
        break;
      case 'Regular':
        count = regularCupCount;
        break;
      case 'Large':
        count = largeCupCount;
        break;
    }

    return GestureDetector(
      onTap: () => _showCategoryDialog(title, color),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
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
      final doc =
          await firestore
              .collection('inventory')
              .doc('sales')
              .collection('daily_sales')
              .doc(widget.username)
              .get();

      Navigator.of(context).pop();

      if (doc.exists && doc.data() != null) {
        _displayCategoryDetails(categoryTitle, cardColor, doc.data()!);
      } else {
        _showErrorSnackBar('No data found for this category');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar('Failed to load category details: $e');
    }
  }

  void _displayCategoryDetails(
    String categoryTitle,
    Color cardColor,
    Map<String, dynamic> data,
  ) {
    Map<String, dynamic> categoryData = {};
    Map<String, dynamic> categoryItems = {}; // For detailed items breakdown
    String dataKey = '';

    // Determine which data to show based on category
    switch (categoryTitle) {
      case 'Silog':
        dataKey = 'silogCount';
        categoryData = _extractCategoryData(data, [
          'silogCount',
          'silog',
          'silogs',
          'silogItems',
        ]);
        categoryItems = _extractCategoryData(data, [
          'silogCategories',
          'silogDetailedItems',
        ]);
        break;
      case 'Snacks':
        dataKey = 'snackCount';
        categoryData = _extractCategoryData(data, [
          'snackCount',
          'snack',
          'snacks',
          'snackItems',
        ]);
        categoryItems = _extractCategoryData(data, [
          'snackCategories',
          'snackDetailedItems',
        ]);
        break;
      case 'Regular':
        dataKey = 'regularCupCount';
        categoryData = _extractCategoryData(data, [
          'regularCupCount',
          'regular',
          'regularCup',
          'regularItems',
        ]);
        categoryItems = _extractCategoryData(data, [
          'regularCupCategories',
          'regularCupDetailedItems',
        ]);
        break;
      case 'Large':
        dataKey = 'largeCupCount';
        categoryData = _extractCategoryData(data, [
          'largeCupCount',
          'large',
          'largeCup',
          'largeItems',
        ]);
        categoryItems = _extractCategoryData(data, [
          'largeCupCategories',
          'largeCupDetailedItems',
        ]);
        break;
    }

    // Use categoryItems first, then fallback to categoryData
    Map<String, dynamic> displayData =
        categoryItems.isNotEmpty ? categoryItems : categoryData;

    // Process the data to show Item - Category format
    Map<String, String> processedData = {}; // Changed to String for categories
    Map<String, int> quantityData = {}; // Separate map for quantities

    if (displayData.isNotEmpty) {
      displayData.forEach((key, value) {
        if (value is Map) {
          // Handle nested structure like "Classic Milktea": {"Blueberry": 1}
          value.forEach((subKey, subValue) {
            int quantity =
                subValue is int
                    ? subValue
                    : (int.tryParse(subValue.toString()) ?? 1);
            processedData['$subKey'] = key; // Item -> Category
            quantityData['$subKey'] = quantity;
          });
        } else if (value is String) {
          // Handle category mapping like "Blueberry": "Classic Milktea"
          processedData[key] = value; // Item -> Category

          // Try to get quantity from the count data
          Map<String, dynamic> countData = _extractCategoryData(data, [
            dataKey,
          ]);
          if (countData.containsKey(key)) {
            int quantity =
                countData[key] is int
                    ? countData[key]
                    : (int.tryParse(countData[key].toString()) ?? 1);
            quantityData[key] = quantity;
          } else {
            quantityData[key] = 1; // Default quantity
          }
        } else {
          // Handle direct key-value pairs for quantities
          int quantity =
              value is int ? value : (int.tryParse(value.toString()) ?? 1);
          processedData[key] = 'No Category'; // Default category
          quantityData[key] = quantity;
        }
      });
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$categoryTitle Details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child:
                processedData.isEmpty
                    ? const Center(
                      child: Text(
                        'No items found in this category',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Item',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: cardColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: cardColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Qty',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: cardColor,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Items list
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children:
                                  processedData.entries.map((entry) {
                                    String item = entry.key;
                                    String category = entry.value;
                                    int quantity = quantityData[item] ?? 1;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              category,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey[600],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              quantity.toString(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: cardColor,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: cardColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _extractCategoryData(
    Map<String, dynamic> data,
    List<String> possibleKeys,
  ) {
    for (String key in possibleKeys) {
      if (data.containsKey(key)) {
        var categoryData = data[key];

        if (categoryData is Map) {
          return Map<String, dynamic>.from(categoryData);
        } else if (categoryData is List) {
          Map<String, dynamic> result = {};
          for (var item in categoryData) {
            String itemName = item.toString();
            result[itemName] = (result[itemName] ?? 0) + 1;
          }
          return result;
        }
      }
    }
    return {};
  }

  Widget _buildExpenseCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed:
                          () => _confirmDeleteExpense(
                            expense['id'],
                            expense['amount'],
                            expense['name'],
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

  void _confirmDeleteExpense(String expenseId, int amount, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'Delete Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "$name" (₱$amount)?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteExpense(expenseId, amount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
