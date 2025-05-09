// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  List<Map<String, dynamic>> dailySalesList = [];
  double monthlySales = 0.0; // ✅ Declare this variable
  bool isLoading = true;
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
      await _loadMonthlySales(); // ✅ Await to ensure complete load
    }
  }

  Future<void> _loadMonthlySales() async {
    final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);
    setState(() {
      isLoading = true;
    });

    try {
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

      if (!mounted) return; // ✅ Prevent using context if widget was disposed
      setState(() {
        monthlySales = totalAmount;
        dailySalesList = sales;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
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

    if (!mounted) return;
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
            Text('Are sure to reset the Monthly Sales?', style: TextStyle(fontSize: 15)),
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
  final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);

  // Get complete data for the selected month
  final snapshot = await FirebaseFirestore.instance
      .collection('monthly_sales')
      .where('date', isEqualTo: monthStr)
      .get();

  // Extract all required data
  double totalExpenses = 0.0;
  Map<String, dynamic> consolidatedData = {
    'largeCupTotal': 0,
    'regularCupTotal': 0,
    'silogTotal': 0,
    'snackTotal': 0,
    'netSales': 0.0,
    'totalSales': 0.0,
    'largeCupCategories': <String, Map<String, int>>{},
    'regularCupCategories': <String, Map<String, int>>{},
    'silogCategories': <String, Map<String, int>>{},
    'snackCategories': <String, Map<String, int>>{},
    'expenses': <Map<String, dynamic>>[],
  };

  // Process all documents for the month
  for (var doc in snapshot.docs) {
    final data = doc.data();
    
    // Extract monthData - directly use the monthData from Firebase
    if (data.containsKey('monthData')) {
      final monthData = data['monthData'];
      if (monthData is Map) {
        consolidatedData['largeCupTotal'] += (monthData['largeCupTotal'] is num) 
            ? (monthData['largeCupTotal'] as num).toInt() 
            : 0;
        consolidatedData['regularCupTotal'] += (monthData['regularCupTotal'] is num) 
            ? (monthData['regularCupTotal'] as num).toInt() 
            : 0;
        consolidatedData['silogTotal'] += (monthData['silogTotal'] is num) 
            ? (monthData['silogTotal'] as num).toInt() 
            : 0;
        consolidatedData['snackTotal'] += (monthData['snackTotal'] is num) 
            ? (monthData['snackTotal'] as num).toInt() 
            : 0;
        consolidatedData['netSales'] += (monthData['netSales'] is num) 
            ? (monthData['netSales'] as num).toDouble() 
            : 0.0;
        consolidatedData['totalSales'] += (monthData['totalSales'] is num) 
            ? (monthData['totalSales'] as num).toDouble() 
            : 0.0;
      }
    }

    // Process user details for category data and expenses
    if (data.containsKey('userDetails')) {
      final userDetails = data['userDetails'];
      if (userDetails is List) {
        for (var userDetail in userDetails) {
          if (userDetail is Map) {
            // Process category data from each user
            _processDetailedItems(userDetail, 'largeCupDetailedItems', consolidatedData['largeCupCategories']);
            _processDetailedItems(userDetail, 'regularCupDetailedItems', consolidatedData['regularCupCategories']);
            _processDetailedItems(userDetail, 'silogDetailedItems', consolidatedData['silogCategories']);
            _processDetailedItems(userDetail, 'snackDetailedItems', consolidatedData['snackCategories']);
            
            // Process expenses
            if (userDetail.containsKey('expenses')) {
              final expenses = userDetail['expenses'];
              if (expenses is Map) {
                expenses.forEach((key, expenseData) {
                  if (expenseData is Map) {
                    final amount = (expenseData['amount'] is num) ? (expenseData['amount'] as num).toDouble() : 0.0;
                    final name = expenseData['name'] ?? 'Unknown';
                    
                    totalExpenses += amount;
                    consolidatedData['expenses'].add({
                      'name': name,
                      'amount': amount,
                    });
                  }
                });
              }
            }
          }
        }
      }
    }
  }

  // Create Header Function for consistency across pages
  pw.Widget _buildReportHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Monthly Sales Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Report Date: $reportDate', style: pw.TextStyle(fontSize: 14)),
        pw.Text('Month: $monthStr', style: pw.TextStyle(fontSize: 14)),
        pw.Divider(),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // First page - Summary
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => _buildReportHeader(),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
      ),
      build: (context) => [
        // Summary Section
        pw.Text('SUMMARY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _buildPdfSummaryTable(consolidatedData),
        pw.SizedBox(height: 20),
        
        // Large Cup Categories
        pw.Text('PRODUCT BREAKDOWN', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Large Cup Products', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        _buildPdfCategoryTable(consolidatedData['largeCupCategories']),
        pw.SizedBox(height: 15),
        
        // Regular Cup Categories
        pw.Text('Regular Cup Products', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        _buildPdfCategoryTable(consolidatedData['regularCupCategories']),
        pw.SizedBox(height: 15),
      ],
    ),
  );

  // Second page - More Product Categories and Expenses
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => _buildReportHeader(),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
      ),
      build: (context) => [
        // Silog Categories
        pw.Text('Silog Products', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        _buildPdfCategoryTable(consolidatedData['silogCategories']),
        pw.SizedBox(height: 15),
        
        // Snack Categories
        pw.Text('Snack Products', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        _buildPdfCategoryTable(consolidatedData['snackCategories']),
        pw.SizedBox(height: 20),
        
        // Expenses Section
        pw.Text('EXPENSES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _buildPdfExpensesTable(consolidatedData['expenses'], totalExpenses),
        
        // Daily Sales Breakdown (if needed)
        if (dailySalesList.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('DAILY SALES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildPdfDailySalesTable(dailySalesList),
        ],
        
        // Profit calculation
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total Sales:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('${consolidatedData['totalSales'].toStringAsFixed(2)}', 
                   style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total Expenses:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('${totalExpenses.toStringAsFixed(2)}', 
                   style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Divider(thickness: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Net Profit:', 
                   style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('${(consolidatedData['totalSales'] - totalExpenses).toStringAsFixed(2)}', 
                   style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

// Helper method to process detailed items with proper display names
void _processDetailedItems(Map<dynamic, dynamic> userDetail, String itemsKey, Map<String, Map<String, int>> targetMap) {
  if (userDetail.containsKey(itemsKey)) {
    final items = userDetail[itemsKey];
    if (items is Map) {
      items.forEach((key, value) {
        String itemName = key.toString();
        
        // Extract category and flavor from the item name (if no hyphen, just use the name as is)
        String category = itemName;
        String flavor = '';
        
        if (itemsKey == 'regularCupDetailedItems' || itemsKey == 'largeCupDetailedItems') {
          flavor = itemName;
          
          // Try to find the category from categories (e.g., "Classic Milktea")
          if (userDetail.containsKey('regularCupCategories') && itemsKey == 'regularCupDetailedItems') {
            userDetail['regularCupCategories'].forEach((catKey, catValue) {
              if (catKey.toString() == flavor) {
                category = catValue.toString();
              }
            });
          } else if (userDetail.containsKey('largeCupCategories') && itemsKey == 'largeCupDetailedItems') {
            userDetail['largeCupCategories'].forEach((catKey, catValue) {
              if (catKey.toString() == flavor) {
                category = catValue.toString();
              }
            });
          }
          
          // Format display name
          String displayName = "$category - $flavor";
          
          if (!targetMap.containsKey(displayName)) {
            targetMap[displayName] = {'quantity': 0};
          }
          
          int quantity = value is num ? value.toInt() : 0;
          targetMap[displayName]!['quantity'] = (targetMap[displayName]!['quantity'] ?? 0) + quantity;
        } else {
          // For non-drink items, just use the name as is
          if (!targetMap.containsKey(itemName)) {
            targetMap[itemName] = {'quantity': 0};
          }
          
          int quantity = value is num ? value.toInt() : 0;
          targetMap[itemName]!['quantity'] = (targetMap[itemName]!['quantity'] ?? 0) + quantity;
        }
      });
    }
  }
}

// Helper method to build the summary table
pw.Widget _buildPdfSummaryTable(Map<String, dynamic> data) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _pdfTableCell('Category', isHeader: true),
          _pdfTableCell('Count', isHeader: true),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfTableCell('Large Cup Total'),
          _pdfTableCell('${data['largeCupTotal']}'),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfTableCell('Regular Cup Total'),
          _pdfTableCell('${data['regularCupTotal']}'),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfTableCell('Silog Total'),
          _pdfTableCell('${data['silogTotal']}'),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfTableCell('Snack Total'),
          _pdfTableCell('${data['snackTotal']}'),
        ],
      ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _pdfTableCell('Net Sales'),
          _pdfTableCell('${data['netSales'].toStringAsFixed(2)}'),
        ],
      ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _pdfTableCell('Total Sales'),
          _pdfTableCell('${data['totalSales'].toStringAsFixed(2)}'),
        ],
      ),
    ],
  );
}

// Helper method to build category tables
pw.Widget _buildPdfCategoryTable(Map<String, Map<String, int>> categories) {
  if (categories.isEmpty) {
    return pw.Text('No data available', style: const pw.TextStyle(color: PdfColors.grey));
  }

  final rows = <pw.TableRow>[];
  
  // Header row
  rows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _pdfTableCell('Product Name', isHeader: true),
        _pdfTableCell('Quantity', isHeader: true),
      ],
    ),
  );

  // Data rows
  categories.forEach((name, details) {
    String productName = name;
    String quantity = (details['quantity'] ?? 0).toString();
    
    rows.add(
      pw.TableRow(
        children: [
          _pdfTableCell(productName),
          _pdfTableCell(quantity),
        ],
      ),
    );
  });

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey),
    children: rows,
  );
}

// Helper method to build expenses table
pw.Widget _buildPdfExpensesTable(List<Map<String, dynamic>> expenses, double totalExpenses) {
  if (expenses.isEmpty) {
    return pw.Text('No expenses recorded', style: const pw.TextStyle(color: PdfColors.grey));
  }

  final rows = <pw.TableRow>[];
  
  // Header row
  rows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _pdfTableCell('Item', isHeader: true),
        _pdfTableCell('Amount', isHeader: true),
      ],
    ),
  );

  // Data rows
  for (var expense in expenses) {
    rows.add(
      pw.TableRow(
        children: [
          _pdfTableCell(expense['name'] ?? 'Unknown'),
          _pdfTableCell('${(expense['amount'] as num).toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  // Total row
  rows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _pdfTableCell('Total Expenses', isHeader: true),
        _pdfTableCell('${totalExpenses.toStringAsFixed(2)}', isHeader: true),
      ],
    ),
  );

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey),
    children: rows,
  );
}

// Helper method to build daily sales table
pw.Widget _buildPdfDailySalesTable(List<Map<String, dynamic>> salesList) {
  final rows = <pw.TableRow>[];
  
  // Header row
  rows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _pdfTableCell('Date', isHeader: true),
        _pdfTableCell('Amount', isHeader: true),
      ],
    ),
  );

  // Data rows
  for (var sale in salesList) {
    rows.add(
      pw.TableRow(
        children: [
          _pdfTableCell(sale['date']),
          _pdfTableCell((sale['amount'] as num).toStringAsFixed(2)),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey),
    children: rows,
  );
}

// Helper method to create table cells with consistent formatting
pw.Widget _pdfTableCell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: isHeader ? pw.FontWeight.bold : null,
      ),
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
      body: isLoading
          ? Center(child: LoadingAnimationWidget.fallingDot(color: const Color(0xFF4b8673), size: 80))
          : monthlySales > 0
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
