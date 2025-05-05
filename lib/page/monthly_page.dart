// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cart_data.dart';

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  List<Map<String, dynamic>> dailySalesList = [];
  DateTime selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonthlySales();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select Month',
      fieldHintText: 'Month/Year',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked != null) {
      setState(() => selectedMonth = DateTime(picked.year, picked.month));
      _loadMonthlySales();
    }
  }

  Future<void> _loadMonthlySales() async {
    final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);

    final snapshot = await FirebaseFirestore.instance
        .collection('monthly_sales')
        .where('date', isEqualTo: monthStr)
        .get();

    double totalAmount = 0.0;
    final List<Map<String, dynamic>> sales = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      totalAmount += amount;
      sales.add({'date': doc.id, 'amount': amount});
    }

    setState(() {
      monthlySales = totalAmount;
      dailySalesList = sales;
    });
  }

  Future<void> _resetMonthlySales() async {
    final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);

    final snapshot = await FirebaseFirestore.instance
        .collection('monthly_sales')
        .where('date', isEqualTo: monthStr)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      monthlySales = 0.0;
      dailySalesList.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sales for $monthStr have been reset')),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text('Are sure to reset the Monthly Sales?', style: TextStyle(fontSize: 15),)
              ],
            ),
        backgroundColor: Colors.white,
        actions: [
          ElevatedButton(
            onPressed: () {
              _resetMonthlySales();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff4b8673),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf() async {
    final pdf = pw.Document();
    final reportDate = DateFormat('MMMM d, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Monthly Sales Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Date: $reportDate', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Text('Monthly Sales: ₱${monthlySales.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 20),
            if (dailySalesList.isNotEmpty)
              pw.SizedBox(height: 250, child: _buildSalesGraph(dailySalesList)),
            pw.SizedBox(height: 20),
            pw.Text('Breakdown:', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            ...dailySalesList.map(
              (sale) => pw.Text("${sale['date']}: ₱${(sale['amount'] as double).toStringAsFixed(2)}"),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildSalesGraph(List<Map<String, dynamic>> salesList) {
    double maxAmount = salesList.map((s) => s['amount'] as double).reduce((a, b) => a > b ? a : b);

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey, width: 1)),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: salesList.map((sale) {
          final amount = sale['amount'] as double;
          final height = (amount / maxAmount) * 150;

          return pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('₱${amount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 8)),
                pw.Container(height: height, width: 10, color: PdfColors.blueAccent),
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
    );
  }

  Widget _buildSalesList() {
    return ListView.builder(
      itemCount: dailySalesList.length,
      itemBuilder: (_, index) {
        final sale = dailySalesList[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Card(
            elevation: 3,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              title: Text(sale['date'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Daily Sales:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              trailing: Text(
                '₱${(sale['amount'] as double).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 2, blurRadius: 6)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '₱${monthlySales.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Download PDF', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showResetConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reset', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.calendar, size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text('No monthly sales yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickMonth,
          ),
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: monthlySales > 0
          ? Column(
              children: [
                const SizedBox(height: 10),
                Expanded(child: _buildSalesList()),
                _buildBottomActions(),
              ],
            )
          : _buildEmptyState(),
    );
  }
}
