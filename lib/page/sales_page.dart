import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('daily_sales')
          .doc(formattedDate)
          .collection(widget.username)
          .get();

      final data = snapshot.docs.map((doc) => doc.data()).toList();
      final ids = snapshot.docs.map((doc) => doc.id).toList();

      setState(() {
        salesData = data;
        docIds = ids;
        totalSales = data.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));
      });
    } catch (e) {
      debugPrint("Error fetching sales: $e");
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4b8673),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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
        totalSales = salesData.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));
      });
    } catch (e) {
      debugPrint("Error deleting sale: $e");
    }
  }

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

    int silog = 0, snack = 0, regular = 0, large = 0;
    double sum = 0.0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = data['amount']?.toDouble() ?? 0.0;
      final name = (data['productName'] ?? '').toString().toLowerCase();
      final size = (data['size'] ?? '').toString().toLowerCase();

      sum += amount;
      if (name.contains('silog')) silog++;
      else if (RegExp(r'beef|cheese|egg|stick|fries|combo').hasMatch(name)) snack++;
      if (size == 'regular') regular++;
      else if (size == 'large') large++;
    }

final existingData = existingDoc.exists ? existingDoc.data() as Map<String, dynamic> : {};

final data = {
  'totalSales': (existingData['totalSales'] ?? 0.0) + sum,
  'silogCount': (existingData['silogCount'] ?? 0) + silog,
  'snackCount': (existingData['snackCount'] ?? 0) + snack,
  'regularCupCount': (existingData['regularCupCount'] ?? 0) + regular,
  'largeCupCount': (existingData['largeCupCount'] ?? 0) + large,
  'timestamp': FieldValue.serverTimestamp(),
  'date': today,
};


    await (existingDoc.exists ? inventoryDocRef.update(data) : inventoryDocRef.set({...data, 'username': widget.username}));
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    await fetchSalesData();
  }

  Widget buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.money, size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text('No sales yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget buildSaleItem(Map<String, dynamic> item, int index) {
    final productName = item['productName'] ?? 'Unknown';
    final size = item['size'] ?? 'N/A';
    final addOns = List<String>.from(item['addOns'] ?? []);
    final amount = item['amount']?.toDouble() ?? 0.0;

    return Dismissible(
      key: Key(docIds[index]),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) => _confirmDialog(
        title: 'Confirm Deletion',
        content: 'Are you sure you want to delete this sale?',
        onConfirm: () => deleteSale(index),
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
              Text('Name: $productName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Size: $size', style: const TextStyle(fontSize: 15)),
              if (addOns.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text("Add-ons:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ...addOns.map((addOn) => Text("- $addOn", style: const TextStyle(fontSize: 15))),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text("₱${amount.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
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
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_today)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: salesData.isEmpty
                ? buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: salesData.length,
                    itemBuilder: (context, index) => buildSaleItem(salesData[index], index),
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('₱${totalSales.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _confirmDialog(
                title: 'Confirm Action',
                content: 'Add sales to inventory and reset data?',
                onConfirm: addToInventorySales,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add to Inventory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
