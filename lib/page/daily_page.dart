import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class DailyPage extends StatefulWidget {
  final String username;
  final bool isAdmin;

  const DailyPage({super.key, required this.username, required this.isAdmin});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String today;

  Map<String, dynamic>? dailyData; // For regular user
  Map<String, Map<String, dynamic>> allDailyData = {}; // For admin view

  @override
  void initState() {
    super.initState();
    today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.isAdmin) {
      await loadAllUsersDailyData();
    } else {
      await loadUserDailyData();
    }
  }

  Future<void> loadUserDailyData() async {
    final doc = await firestore
        .collection('daily_records')
        .doc(today)
        .collection('users')
        .doc(widget.username)
        .get();

    if (doc.exists) {
      setState(() {
        dailyData = doc.data();
      });
    } else {
      setState(() {
        dailyData = null;
      });
    }
  }

  Future<void> loadAllUsersDailyData() async {
    final snapshot = await firestore
        .collection('daily_records')
        .doc(today)
        .collection('users')
        .get();

    setState(() {
      allDailyData = {
        for (var doc in snapshot.docs) doc.id: doc.data(),
      };
    });
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
      });
      await _loadData();
    }
  }

  Future<void> _addUserToMonthlySale(String username, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Confirmation'),
          content: const Text('Are you sure to add this to monthly sales?'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide.none,
                ),
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // ✅ Use selected date instead of DateTime.now()
    final DateTime selectedDate = DateTime.parse(today);
    final String formattedDate = DateFormat('MMMM d yyyy').format(selectedDate);
    final String monthKey = DateFormat('MMMM yyyy').format(selectedDate);
    final double netSales = (data['netSales'] ?? 0).toDouble();

    final monthlyDocRef = firestore.collection('monthly_sales').doc(formattedDate);
    final monthlyDocSnap = await monthlyDocRef.get();

    if (monthlyDocSnap.exists) {
      final existingData = monthlyDocSnap.data();
      final double existingAmount = (existingData?['amount'] ?? 0).toDouble();

      await monthlyDocRef.update({
        'amount': existingAmount + netSales,
      });
    } else {
      await monthlyDocRef.set({
        'amount': netSales,
        'date': monthKey,
      });
    }

    await firestore
        .collection('daily_records')
        .doc(today)
        .collection('users')
        .doc(username)
        .delete();

    setState(() {
      allDailyData.remove(username);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$username\'s sales moved to Monthly')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: widget.isAdmin
            ? allDailyData.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.graph, size: 80, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No daily summaries yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView(
                    children: allDailyData.entries
                        .map((entry) => _buildUserSummaryCard(entry.key, entry.value))
                        .toList(),
                  )
            : dailyData == null
                ? const Center(child: Text('No daily summary yet'))
                : _buildUserSummaryCard(widget.username, dailyData!),
      ),
    );
  }

  Widget _buildUserSummaryCard(String username, Map<String, dynamic> data) {
    int totalSales = data['totalSales'] ?? 0;
    int netSales = data['netSales'] ?? 0;
    int silogCount = data['silogCount'] ?? 0;
    int snackCount = data['snackCount'] ?? 0;
    int regularCupCount = data['regularCupCount'] ?? 0;
    int largeCupCount = data['largeCupCount'] ?? 0;
    List expenses = data['expenses'] ?? [];

    double totalExpenses = expenses.fold(
      0.0,
      (sum, e) => sum + (e['amount'] ?? 0),
    );

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('MMMM d, yyyy').format(DateTime.parse(today)),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              'Total Sales: ₱$totalSales',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            if (expenses.isNotEmpty) _buildExpenseCard(expenses, totalExpenses),
            const SizedBox(height: 10),
            Text(
              'Daily Sales: ₱${netSales.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ElevatedButton(
                  onPressed: () => _addUserToMonthlySale(username, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B8673),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add to Monthly Sales',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Text(
          '$count sold',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(List expenses, double total) {
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
            Text(
              'Total Expenses: ₱$total',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
