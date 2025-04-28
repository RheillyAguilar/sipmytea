// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cart_data.dart'; // assume monthlySales is from here

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  List<Map<String, dynamic>> dailySalesList = [];

  @override
  void initState() {
    super.initState();
    _loadMonthlySales();
  }

  Future<void> _loadMonthlySales() async {
    final formattedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    final snapshot = await FirebaseFirestore.instance
        .collection('monthly_sales')
        .where('date', isEqualTo: formattedMonth)
        .get();

    double totalAmount = 0.0;
    List<Map<String, dynamic>> tempList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final docId = doc.id; // e.g., "April 7 2025"
      if (data.containsKey('amount')) {
        double amount = (data['amount'] as num).toDouble();
        totalAmount += amount;
        tempList.add({'date': docId, 'amount': amount});
      }
    }

    setState(() {
      monthlySales = totalAmount;
      dailySalesList = tempList;
    });
  }

  Future<void> _resetMonthlySales() async {
    final snapshot = await FirebaseFirestore.instance.collection('monthly_sales').get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      monthlySales = 0.0;
      dailySalesList.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monthly sales have been reset')),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Reset'),
          content: const Text('Are you sure you want to reset monthly sales?'),
          backgroundColor: const Color(0xFFFAF3E0),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
              onPressed: () {
                _resetMonthlySales();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadPdf() async {
    final pdf = pw.Document();
    String formattedDate = DateFormat('MMMM d, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Monthly Sales Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Date: $formattedDate',
                style: pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Monthly Sales: ₱${monthlySales.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 20),

              if (dailySalesList.isNotEmpty)
                pw.Container(
                  height: 250,
                  child: _buildSalesGraph(dailySalesList),
                ),

              pw.SizedBox(height: 20),
              pw.Text('Breakdown:', style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              ...dailySalesList.map(
                (sale) => pw.Text(
                  "${sale['date']}: ₱${(sale['amount'] as double).toStringAsFixed(2)}",
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildSalesGraph(List<Map<String, dynamic>> salesList) {
    double maxAmount = salesList.map((s) => s['amount'] as double).reduce((a, b) => a > b ? a : b);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 1),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: salesList.map((sale) {
              double amount = sale['amount'] as double;
              double barHeight = (amount / maxAmount) * 150; // max bar height

              return pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      '₱${amount.toStringAsFixed(0)}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    pw.Container(
                      width: 10,
                      height: barHeight,
                      color: PdfColors.blueAccent,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      DateFormat('d').format(DateFormat('MMMM d yyyy').parse(sale['date'])),
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasSales = monthlySales > 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Monthly Sales")),
      backgroundColor: Colors.grey[200],
      body: hasSales
          ? Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: dailySalesList.length,
                    itemBuilder: (context, index) {
                      final sale = dailySalesList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Card(
                          elevation: 3,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: ListTile(
                              title: Text(
                                sale['date'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Daily Sales:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Text(
                                "₱${(sale['amount'] as double).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₱${monthlySales.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _downloadPdf,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Download PDF',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showResetConfirmationDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: Text(
                'No sales yet.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
    );
  }
}
