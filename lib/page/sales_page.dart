import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesPage extends StatefulWidget {
  final String username;
  const SalesPage({super.key, required this.username});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final String formattedDate = DateFormat('MMMM d yyyy').format(DateTime.now());
  double totalSales = 0.0;
  List<Map<String, dynamic>> salesData = [];
  List<String> docIds = [];

  Future<void> fetchSalesData() async {
    try {
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('daily_sales')
          .doc(formattedDate)
          .collection(widget.username)
          .get();

      final data = salesSnapshot.docs.map((doc) => doc.data()).toList();
      final ids = salesSnapshot.docs.map((doc) => doc.id).toList();

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
    }
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

  Future<void> addToInventorySales(BuildContext context) async {
    final now = DateTime.now();
    final formatted = DateFormat('yyyy-MM-dd').format(now);

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

    int silogCount = 0;
    int snackCount = 0;
    int regularCupCount = 0;
    int largeCupCount = 0;
    double totalSales = 0.0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = data['amount']?.toDouble() ?? 0.0;
      final productName = data['productName']?.toString().toLowerCase() ?? '';
      final size = data['size']?.toString().toLowerCase() ?? '';

      totalSales += amount;

      if (productName.contains('silog')) {
        silogCount++;
      } else if (productName.contains(
        RegExp(r'beef|cheese|egg|stick|fries|combo'),
      )) {
        snackCount++;
      }

      if (size == 'regular') {
        regularCupCount++;
      } else if (size == 'large') {
        largeCupCount++;
      }
    }

    if (existingDoc.exists) {
      final data = existingDoc.data()!;
      await inventoryDocRef.update({
        'totalSales': (data['totalSales'] ?? 0.0) + totalSales,
        'silogCount': (data['silogCount'] ?? 0) + silogCount,
        'snackCount': (data['snackCount'] ?? 0) + snackCount,
        'regularCupCount': (data['regularCupCount'] ?? 0) + regularCupCount,
        'largeCupCount': (data['largeCupCount'] ?? 0) + largeCupCount,
        'timestamp': FieldValue.serverTimestamp(),
        'date': formatted,
      });
    } else {
      await inventoryDocRef.set({
        'totalSales': totalSales,
        'silogCount': silogCount,
        'snackCount': snackCount,
        'regularCupCount': regularCupCount,
        'largeCupCount': largeCupCount,
        'timestamp': FieldValue.serverTimestamp(),
        'date': formatted,
        'username': widget.username,
      });
    }

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    await fetchSalesData();
  }

  @override
  void initState() {
    super.initState();
    fetchSalesData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          "Sales",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: salesData.isEmpty
                ? const Center(child: Text("No sales found for this user."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: salesData.length,
                    itemBuilder: (context, index) {
                      final item = salesData[index];
                      final productName = item['productName'] ?? 'Unknown';
                      final size = item['size'] ?? 'N/A';
                      final addOns = List<String>.from(item['addOns'] ?? []);
                      final amount = item['amount']?.toDouble() ?? 0.0;

                      return Dismissible(
                        key: Key(docIds[index]),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text("Confirm Deletion"),
                              content: const Text(
                                "Are you sure you want to delete this sale?",
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text("Cancel"),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          deleteSale(index);
                        },
                        background: Container(
                          color: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerLeft,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        secondaryBackground: Container(
                          color: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Name: $productName',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Size: $size',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                if (addOns.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Add-ons:",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  ...addOns.map(
                                    (addOn) => Text(
                                      "- $addOn",
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    "₱${amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
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
          if (salesData.isNotEmpty)
            Container(
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text(
                              "Confirm Action",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            content: const Text(
                              "Are you sure you want to add sales to inventory and reset data?",
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  addToInventorySales(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF4B8673),
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
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFF4B8673),
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
            ),
        ],
      ),
    );
  }
}
