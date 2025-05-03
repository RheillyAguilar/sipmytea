import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InventoryPage extends StatefulWidget {
  final String username;

  const InventoryPage({super.key, required this.username});

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String today;

  int totalSales = 0;
  int inventoryTotalSales = 0;

  int silogCount = 0;
  int snackCount = 0;
  int regularCupCount = 0;
  int largeCupCount = 0;

  List<Map<String, dynamic>> expenses = [];
  int totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  void clearSalesStats() {
    setState(() {
      totalSales =
          silogCount = snackCount = regularCupCount = largeCupCount = 0;
    });
  }

  Future<void> _loadData() async {
    await loadExpenses();
    await loadInventorySales();
    await loadTodaysSales();
  }

  Future<void> loadExpenses() async {
    final snapshot = await firestore
        .collection('inventory')
        .doc('expenses')
        .collection('daily_expenses')
        .doc(widget.username)
        .collection('expenses')
        .get();

    final loadedExpenses = snapshot.docs.map((doc) {
      final data = doc.data();
      return {'name': data['name'] ?? '', 'amount': data['amount'] ?? 0};
    }).toList();

    final total = loadedExpenses.fold<int>(
      0,
      (sum, item) => sum + (item['amount'] as int),
    );

    setState(() {
      expenses = loadedExpenses;
      totalExpenses = total;
    });
  }

  Future<void> loadTodaysSales() async {
    final snapshot = await firestore
        .collection('daily_sales')
        .doc(today)
        .collection(widget.username)
        .get();

    int total = 0, silog = 0, snack = 0, reg = 0, large = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      total += (data['amount'] as num).toInt();

      final name = data['productName']?.toString().toLowerCase() ?? '';
      if (name.contains('silog')) silog++;
      if (name.contains('snack')) snack++;

      final size = data['size']?.toString().toLowerCase() ?? '';
      if (size == 'regular') reg++;
      if (size == 'large') large++;
    }

    setState(() {
      totalSales = total;
      silogCount = silog;
      snackCount = snack;
      regularCupCount = reg;
      largeCupCount = large;
    });
  }

  Future<void> loadInventorySales() async {
    final doc = await firestore
        .collection('inventory')
        .doc('sales')
        .collection('daily_sales')
        .doc(widget.username)
        .get();

    if (doc.exists) {
      final data = doc.data();
      setState(() {
        inventoryTotalSales = (data?['totalSales'] ?? 0).toInt();
        silogCount = data?['silogCount'] ?? 0;
        snackCount = data?['snackCount'] ?? 0;
        regularCupCount = data?['regularCupCount'] ?? 0;
        largeCupCount = data?['largeCupCount'] ?? 0;
      });
    }
  }

  Future<void> addToDailySales() async {
    final docRef = firestore
        .collection('daily_records')
        .doc(today)
        .collection('users')
        .doc(widget.username);

    final netSales = inventoryTotalSales - totalExpenses;
    final existingDoc = await docRef.get();

    if (existingDoc.exists) {
      final currentData = existingDoc.data()!;
      await docRef.update({
        'totalSales': (currentData['totalSales'] ?? 0) + inventoryTotalSales,
        'silogCount': (currentData['silogCount'] ?? 0) + silogCount,
        'snackCount': (currentData['snackCount'] ?? 0) + snackCount,
        'regularCupCount':
            (currentData['regularCupCount'] ?? 0) + regularCupCount,
        'largeCupCount': (currentData['largeCupCount'] ?? 0) + largeCupCount,
        'expenses': expenses,
        'totalExpenses': (currentData['totalExpenses'] ?? 0) + totalExpenses,
        'netSales': (currentData['netSales'] ?? 0) + netSales,
        'timestamp': Timestamp.now(),
        'username': widget.username,
      });
    } else {
      await docRef.set({
        'totalSales': inventoryTotalSales,
        'silogCount': silogCount,
        'snackCount': snackCount,
        'regularCupCount': regularCupCount,
        'largeCupCount': largeCupCount,
        'expenses': expenses,
        'totalExpenses': totalExpenses,
        'netSales': netSales,
        'timestamp': Timestamp.now(),
        'username': widget.username,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to Daily Sales and cleared today\'s data'),
      ),
    );
  }

  Future<void> deleteTodaySales() async {
    final batch = firestore.batch();

    final userSales = await firestore
        .collection('daily_sales')
        .doc(today)
        .collection(widget.username)
        .get();

    for (var doc in userSales.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.tryParse(today) ?? DateTime.now();

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        today = DateFormat('yyyy-MM-dd').format(picked);
        inventoryTotalSales = 0;
        totalExpenses = 0;
        expenses.clear();
        clearSalesStats();
      });
      await _loadData();
    }
  }

  Future<void> _confirmDailySales() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        backgroundColor: Colors.white,
        content: const Text(
          'Are you sure you want to add to daily sales? This will clear today\'s sales and expenses.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await addToDailySales();
              await deleteTodaySales();
              await firestore
                  .collection('inventory')
                  .doc('expenses')
                  .collection('daily_expenses')
                  .doc(widget.username)
                  .collection('expenses')
                  .get()
                  .then((snapshot) {
                for (var doc in snapshot.docs) {
                  doc.reference.delete();
                }
              });
              await firestore
                  .collection('inventory')
                  .doc('sales')
                  .collection('daily_sales')
                  .doc(widget.username)
                  .delete();
              clearSalesStats();
              setState(() {
                expenses.clear();
                totalExpenses = 0;
                inventoryTotalSales = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4b8673),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
              'Add Expense',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Expense Name',
                filled: true,
                fillColor: const Color(0xFFF6F6F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
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
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final amount =
                        int.tryParse(amountController.text.trim()) ?? 0;

                    if (name.isNotEmpty && amount > 0) {
                      final expenseData = {
                        'name': name,
                        'amount': amount,
                        'date': today,
                        'timestamp': Timestamp.now(),
                        'username': widget.username,
                      };

                      try {
                        await firestore
                            .collection('inventory')
                            .doc('expenses')
                            .collection('daily_expenses')
                            .doc(widget.username)
                            .collection('expenses')
                            .add(expenseData);

                        setState(() {
                          expenses.add({'name': name, 'amount': amount});
                          totalExpenses += amount;
                        });

                        Navigator.of(context).pop();
                      } catch (e) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to save expense'),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter valid expense details',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B8673),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, int count, Color color) {
    return Card(
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
    );
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
                trailing: Text(
                  '₱${expense['amount']}',
                  style: const TextStyle(fontSize: 15),
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

  Widget _buildBottomBar() {
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
                '₱${(inventoryTotalSales - totalExpenses).toStringAsFixed(2)}',
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
              'Confirm Daily Sales',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasSalesOrExpenses = inventoryTotalSales > 0 || totalExpenses > 0;

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: hasSalesOrExpenses
            ? Column(
                children: [
                  if (inventoryTotalSales > 0)
                    Card(
                      color: Colors.grey[100],
                      child: ListTile(
                        title: Text(
                          'Total Sales: ₱$inventoryTotalSales',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (inventoryTotalSales > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildCategoryCard(
                            'Silog',
                            silogCount,
                            const Color(0xFFe1ad01),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCategoryCard(
                            'Snacks',
                            snackCount,
                            const Color(0xFFb8286d),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCategoryCard(
                            'Regular Cups',
                            regularCupCount,
                            const Color(0xFF25b3b9),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCategoryCard(
                            'Large Cups',
                            largeCupCount,
                            const Color(0xFF166e71),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (expenses.isNotEmpty) _buildExpenseCard(),
                  const Spacer(),
                ],
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No inventory yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExpenseModalSheet,
        backgroundColor: const Color(0xFF4b8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: hasSalesOrExpenses ? _buildBottomBar() : null,
    );
  }
}
