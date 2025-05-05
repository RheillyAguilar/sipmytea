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
  late String selectedDate;

  Map<String, dynamic>? dailyData;
  Map<String, Map<String, dynamic>> allDailyData = {};

  @override
  void initState() {
    super.initState();
    selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    widget.isAdmin ? await _loadAllUsersDailyData() : await _loadUserDailyData();
  }

  Future<void> _loadUserDailyData() async {
    final doc = await firestore
        .collection('daily_records')
        .doc(selectedDate)
        .collection('users')
        .doc(widget.username)
        .get();

    setState(() => dailyData = doc.exists ? doc.data() : null);
  }

  Future<void> _loadAllUsersDailyData() async {
    final snapshot = await firestore
        .collection('daily_records')
        .doc(selectedDate)
        .collection('users')
        .get();

    setState(() {
      allDailyData = {for (var doc in snapshot.docs) doc.id: doc.data()};
    });
  }

  Future<void> _pickDate() async {
    final DateTime initial = DateTime.tryParse(selectedDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = DateFormat('yyyy-MM-dd').format(picked));
      await _loadData();
    }
  }

  Future<void> _addUserToMonthlySale(String username, Map<String, dynamic> data) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirmation'),
        content: const Text('Are you sure to add this to monthly sales?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B8673),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final DateTime parsedDate = DateTime.parse(selectedDate);
    final String formattedDate = DateFormat('MMMM d yyyy').format(parsedDate);
    final String monthKey = DateFormat('MMMM yyyy').format(parsedDate);
    final double netSales = (data['netSales'] ?? 0).toDouble();

    final docRef = firestore.collection('monthly_sales').doc(formattedDate);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      final currentAmount = (docSnap.data()?['amount'] ?? 0).toDouble();
      await docRef.update({'amount': currentAmount + netSales});
    } else {
      await docRef.set({'amount': netSales, 'date': monthKey});
    }

    await firestore
        .collection('daily_records')
        .doc(selectedDate)
        .collection('users')
        .doc(username)
        .delete();

    setState(() => allDailyData.remove(username));

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
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: widget.isAdmin ? _buildAdminBody() : _buildUserBody(),
      ),
    );
  }

  Widget _buildAdminBody() {
    if (allDailyData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.graph, size: 80, color: Colors.grey),
            SizedBox(height: 12),
            Text('No daily summaries yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      children: allDailyData.entries
          .map((entry) => _buildUserSummaryCard(entry.key, entry.value))
          .toList(),
    );
  }

  Widget _buildUserBody() {
    if (dailyData == null) {
      return const Center(child: Text('No daily summary yet'));
    }
    return _buildUserSummaryCard(widget.username, dailyData!);
  }

  Widget _buildUserSummaryCard(String username, Map<String, dynamic> data) {
    final int totalSales = data['totalSales'] ?? 0;
    final int netSales = data['netSales'] ?? 0;
    final int silogCount = data['silogCount'] ?? 0;
    final int snackCount = data['snackCount'] ?? 0;
    final int regularCupCount = data['regularCupCount'] ?? 0;
    final int largeCupCount = data['largeCupCount'] ?? 0;
    final List expenses = data['expenses'] ?? [];

    final double totalExpenses = expenses.fold(
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
            Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text(
              DateFormat('MMMM d, yyyy').format(DateTime.parse(selectedDate)),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text('Total Sales: ₱$totalSales',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            if (expenses.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildExpenseCard(expenses, totalExpenses),
            ],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add to Monthly Sales',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
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
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text('$count sold', style: const TextStyle(color: Colors.white)),
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
            ...expenses.map((expense) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(expense['name'], style: const TextStyle(fontSize: 15)),
                  trailing: Text('₱${expense['amount']}', style: const TextStyle(fontSize: 15)),
                )),
            const Divider(),
            Text('Total Expenses: ₱$total',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
