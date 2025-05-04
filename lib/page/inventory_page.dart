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

  int inventoryTotalSales = 0;
  int totalExpenses = 0;
  int silogCount = 0, snackCount = 0, regularCupCount = 0, largeCupCount = 0;

  List<Map<String, dynamic>> expenses = [];

  @override
  void initState() {
    super.initState();
    today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  void _clearSalesStats() {
    setState(() {
      silogCount = snackCount = regularCupCount = largeCupCount = 0;
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadExpenses(),
      _loadInventorySales(),
    ]);
  }

  Future<void> _loadExpenses() async {
    final snapshot = await firestore
        .collection('inventory')
        .doc('expenses')
        .collection('daily_expenses')
        .doc(widget.username)
        .collection('expenses')
        .get();

    final loadedExpenses = snapshot.docs.map((doc) => {
          'name': doc['name'] ?? '',
          'amount': doc['amount'] ?? 0,
        }).toList();

    setState(() {
      expenses = loadedExpenses;
      totalExpenses =
          loadedExpenses.fold(0, (sum, e) => sum + (e['amount'] as int));
    });
  }

  Future<void> _loadInventorySales() async {
    final doc = await firestore
        .collection('inventory')
        .doc('sales')
        .collection('daily_sales')
        .doc(widget.username)
        .get();

    if (!doc.exists || doc['date'] != today) {
      _clearSalesStats();
      setState(() => inventoryTotalSales = 0);
      return;
    }

    setState(() {
      inventoryTotalSales = (doc['totalSales'] ?? 0).toInt();
      silogCount = doc['silogCount'] ?? 0;
      snackCount = doc['snackCount'] ?? 0;
      regularCupCount = doc['regularCupCount'] ?? 0;
      largeCupCount = doc['largeCupCount'] ?? 0;
    });
  }

  Future<void> _addToDailySales() async {
    final netSales = inventoryTotalSales - totalExpenses;
    final docRef = firestore
        .collection('daily_records')
        .doc(today)
        .collection('users')
        .doc(widget.username);

    final currentData = (await docRef.get()).data();

    final updatedData = {
      'totalSales': (currentData?['totalSales'] ?? 0) + inventoryTotalSales,
      'silogCount': (currentData?['silogCount'] ?? 0) + silogCount,
      'snackCount': (currentData?['snackCount'] ?? 0) + snackCount,
      'regularCupCount':
          (currentData?['regularCupCount'] ?? 0) + regularCupCount,
      'largeCupCount': (currentData?['largeCupCount'] ?? 0) + largeCupCount,
      'expenses': expenses,
      'totalExpenses': (currentData?['totalExpenses'] ?? 0) + totalExpenses,
      'netSales': (currentData?['netSales'] ?? 0) + netSales,
      'timestamp': Timestamp.now(),
      'username': widget.username,
    };

    currentData == null ? await docRef.set(updatedData) : await docRef.update(updatedData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to Daily Sales and cleared today\'s data')),
    );
  }

  Future<void> _clearFirestoreData() async {
    final batch = firestore.batch();

    // Delete sales
    final sales = await firestore
        .collection('daily_sales')
        .doc(today)
        .collection(widget.username)
        .get();
    for (var doc in sales.docs) {
      batch.delete(doc.reference);
    }

    // Delete expenses
    final expensesSnapshot = await firestore
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

  Future<void> _confirmDailySales() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to add to daily sales? This will clear today\'s data.'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addToDailySales();
              await _clearFirestoreData();
              setState(() {
                _clearSalesStats();
                expenses.clear();
                totalExpenses = 0;
                inventoryTotalSales = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4b8673),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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
        child: _buildExpenseForm(nameController, amountController),
      ),
    );
  }

  Widget _buildExpenseForm(TextEditingController nameController, TextEditingController amountController) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Add Expense', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildTextField(controller: nameController, label: 'Expense Name'),
        const SizedBox(height: 12),
        _buildTextField(controller: amountController, label: 'Amount', isNumber: true),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
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
                } catch (_) {
                  Navigator.of(context).pop();
                  _showErrorSnackBar('Failed to save expense');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasData = inventoryTotalSales > 0 || totalExpenses > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: hasData ? _buildContent() : _buildEmptyState(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExpenseModalSheet,
        backgroundColor: const Color(0xFF4b8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: hasData ? _buildBottomBar() : null,
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        if (inventoryTotalSales > 0)
          Card(
            color: Colors.grey[100],
            child: ListTile(
              title: Text('Total Sales: ₱$inventoryTotalSales', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        const SizedBox(height: 20),
        if (inventoryTotalSales > 0) ...[
          Row(
            children: [
              Expanded(child: _buildCategoryCard('Silog', silogCount, const Color(0xFFe1ad01))),
              const SizedBox(width: 10),
              Expanded(child: _buildCategoryCard('Snacks', snackCount, const Color(0xFFb8286d))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCategoryCard('Regular Cups', regularCupCount, const Color(0xFF25b3b9))),
              const SizedBox(width: 10),
              Expanded(child: _buildCategoryCard('Large Cups', largeCupCount, const Color(0xFF166e71))),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (expenses.isNotEmpty) _buildExpenseCard(),
        const Spacer(),
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
          Text('No inventory yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, int count, Color color) {
    return Card(
      color: color,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text('$count sold', style: const TextStyle(color: Colors.white)),
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
            const Text('Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...expenses.map(
              (expense) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(expense['name'], style: const TextStyle(fontSize: 15)),
                trailing: Text('₱${expense['amount']}', style: const TextStyle(fontSize: 15)),
              ),
            ),
            const Divider(),
            Text('Total Expenses: ₱$totalExpenses', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final netSales = (inventoryTotalSales - totalExpenses).toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Sales:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('₱$netSales', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _confirmDailySales,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A705E),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm Daily Sales', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
