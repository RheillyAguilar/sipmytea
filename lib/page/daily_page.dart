// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
  bool isLoading = true;

  // These variables are for the current user's data only
  int silogCount = 0;
  int snackCount = 0;
  int regularCupCount = 0;
  int largeCupCount = 0;

  @override
  void initState() {
    super.initState();
    selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      widget.isAdmin
          ? await _loadAllUsersDailyData()
          : await _loadUserDailyData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserDailyData() async {
    final doc =
        await firestore
            .collection('daily_records')
            .doc(selectedDate)
            .collection('users')
            .doc(widget.username)
            .get();

    setState(() {
      dailyData = doc.exists ? doc.data() : null;
      if (dailyData != null) {
        silogCount = dailyData!['silogCount'] ?? 0;
        snackCount = dailyData!['snackCount'] ?? 0;
        regularCupCount = dailyData!['regularCupCount'] ?? 0;
        largeCupCount = dailyData!['largeCupCount'] ?? 0;
      }
    });
  }

  Future<void> _loadAllUsersDailyData() async {
    final snapshot =
        await firestore
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

  // [Keep all the existing _addUserToMonthlySale and _mergeDetailedData methods unchanged]
  Future<void> _addUserToMonthlySale(
    String username,
    Map<String, dynamic> data,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              'Are you sure you want to add this to the Monthly Sale?',
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B8673),
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
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
      final DateTime parsedDate = DateTime.parse(selectedDate);
      final String formattedDate = DateFormat('MMMM d yyyy').format(parsedDate);
      final String monthKey = DateFormat('MMMM yyyy').format(parsedDate);
      final double netSales = (data['netSales'] ?? 0).toDouble();
      final int cashTotal = data['cashTotal'] ?? 0;
      final int gcashTotal = data['gcashTotal'] ?? 0;

      Map<String, dynamic> formattedExpenses = {};
      final dynamic expensesData = data['expenses'];
      
      if (expensesData != null) {
        if (expensesData is Map) {
          formattedExpenses = Map<String, dynamic>.from(expensesData);
        } 
        else if (expensesData is List && expensesData.isNotEmpty) {
          for (int i = 0; i < expensesData.length; i++) {
            formattedExpenses[i.toString()] = expensesData[i];
          }
        }
        
        print('Expenses data type: ${expensesData.runtimeType}');
        print('Formatted expenses: $formattedExpenses');
      }

      Map<String, dynamic> userDetailEntry = {
        'username': username,
        'amount': netSales,
        'totalSales': data['totalSales'] ?? 0,
        'netSales': netSales,
        'cashTotal': cashTotal,
        'gcashTotal': gcashTotal,
        'date': selectedDate,
        'formattedDate': formattedDate,

        'silogCount': data['silogCount'] ?? 0,
        'snackCount': data['snackCount'] ?? 0,
        'regularCupCount': data['regularCupCount'] ?? 0,
        'largeCupCount': data['largeCupCount'] ?? 0,

        'silogCategories': data['silogCategories'] ?? {},
        'silogDetailedItems': data['silogDetailedItems'] ?? {},
        'snackCategories': data['snackCategories'] ?? {},
        'snackDetailedItems': data['snackDetailedItems'] ?? {},
        'regularCupCategories': data['regularCupCategories'] ?? {},
        'regularCupDetailedItems': data['regularCupDetailedItems'] ?? {},
        'largeCupCategories': data['largeCupCategories'] ?? {},
        'largeCupDetailedItems': data['largeCupDetailedItems'] ?? {},
      };

      if (formattedExpenses.isNotEmpty) {
        userDetailEntry['expenses'] = formattedExpenses;
      }

      final docRef = firestore.collection('monthly_sales').doc(formattedDate);
      final docSnap = await docRef.get();

      final batch = firestore.batch();

      if (docSnap.exists) {
        final Map<String, dynamic> existingData = docSnap.data() ?? {};
        final List<dynamic> existingUsers = existingData['users'] ?? [];
        final List<dynamic> existingUserDetails = existingData['userDetails'] ?? [];
        final Map<String, dynamic> existingMonthData = existingData['monthData'] ?? {};
        
        Map<String, dynamic> updatedMonthData = {
          'silogTotal': (existingMonthData['silogTotal'] ?? 0) + (data['silogCount'] ?? 0),
          'snackTotal': (existingMonthData['snackTotal'] ?? 0) + (data['snackCount'] ?? 0),
          'regularCupTotal': (existingMonthData['regularCupTotal'] ?? 0) + (data['regularCupCount'] ?? 0),
          'largeCupTotal': (existingMonthData['largeCupTotal'] ?? 0) + (data['largeCupCount'] ?? 0),
          'totalSales': (existingMonthData['totalSales'] ?? 0) + (data['totalSales'] ?? 0),
          'netSales': (existingMonthData['netSales'] ?? 0) + netSales,
          'cashTotal': (existingMonthData['cashTotal'] ?? 0) + cashTotal,
          'gcashTotal': (existingMonthData['gcashTotal'] ?? 0) + gcashTotal,
        };

        int existingUserIndex = -1;
        for (int i = 0; i < existingUserDetails.length; i++) {
          if (existingUserDetails[i]['username'] == username) {
            existingUserIndex = i;
            break;
          }
        }

        if (existingUserIndex >= 0) {
          final Map<String, dynamic> existingUserData = Map<String, dynamic>.from(existingUserDetails[existingUserIndex]);
          
          existingUserData['amount'] = (existingUserData['amount'] ?? 0) + netSales;
          existingUserData['totalSales'] = (existingUserData['totalSales'] ?? 0) + (data['totalSales'] ?? 0);
          existingUserData['netSales'] = (existingUserData['netSales'] ?? 0) + netSales;
          existingUserData['cashTotal'] = (existingUserData['cashTotal'] ?? 0) + cashTotal;
          existingUserData['gcashTotal'] = (existingUserData['gcashTotal'] ?? 0) + gcashTotal;
          
          existingUserData['silogCount'] = (existingUserData['silogCount'] ?? 0) + (data['silogCount'] ?? 0);
          existingUserData['snackCount'] = (existingUserData['snackCount'] ?? 0) + (data['snackCount'] ?? 0);
          existingUserData['regularCupCount'] = (existingUserData['regularCupCount'] ?? 0) + (data['regularCupCount'] ?? 0);
          existingUserData['largeCupCount'] = (existingUserData['largeCupCount'] ?? 0) + (data['largeCupCount'] ?? 0);
          
          _mergeDetailedData(existingUserData, data, 'silogCategories');
          _mergeDetailedData(existingUserData, data, 'silogDetailedItems');
          _mergeDetailedData(existingUserData, data, 'snackCategories');
          _mergeDetailedData(existingUserData, data, 'snackDetailedItems');
          _mergeDetailedData(existingUserData, data, 'regularCupCategories');
          _mergeDetailedData(existingUserData, data, 'regularCupDetailedItems');
          _mergeDetailedData(existingUserData, data, 'largeCupCategories');
          _mergeDetailedData(existingUserData, data, 'largeCupDetailedItems');
          
          if (formattedExpenses.isNotEmpty) {
            Map<String, dynamic> existingExpenses = Map<String, dynamic>.from(existingUserData['expenses'] ?? {});
            
            formattedExpenses.forEach((key, value) {
              String uniqueKey = '${existingExpenses.length}_${DateTime.now().millisecondsSinceEpoch}';
              existingExpenses[uniqueKey] = value;
            });
            
            existingUserData['expenses'] = existingExpenses;
          }
          
          existingUserDetails[existingUserIndex] = existingUserData;
        } else {
          existingUsers.add(username);
          existingUserDetails.add(userDetailEntry);
        }

        batch.update(docRef, {
          'amount': FieldValue.increment(netSales),
          'users': existingUsers,
          'userDetails': existingUserDetails,
          'monthData': updatedMonthData,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        batch.set(docRef, {
          'amount': netSales,
          'date': monthKey,
          'users': [username],
          'userDetails': [userDetailEntry],
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'monthData': {
            'silogTotal': data['silogCount'] ?? 0,
            'snackTotal': data['snackCount'] ?? 0,
            'regularCupTotal': data['regularCupCount'] ?? 0,
            'largeCupTotal': data['largeCupCount'] ?? 0,
            'totalSales': data['totalSales'] ?? 0,
            'netSales': netSales,
            'cashTotal': cashTotal,
            'gcashTotal': gcashTotal,
          },
        });
      }

      final dailyRecordRef = firestore
          .collection('daily_records')
          .doc(selectedDate)
          .collection('users')
          .doc(username);
      batch.delete(dailyRecordRef);

      await batch.commit();

      setState(() => allDailyData.remove(username));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully added to monthly sales'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _mergeDetailedData(Map<String, dynamic> existingData, Map<String, dynamic> newData, String field) {
    Map<String, dynamic> existingMap = Map<String, dynamic>.from(existingData[field] ?? {});
    Map<String, dynamic> newMap = Map<String, dynamic>.from(newData[field] ?? {});
    
    newMap.forEach((key, value) {
      if (existingMap.containsKey(key)) {
        if (value is num) {
          existingMap[key] = (existingMap[key] ?? 0) + value;
        } 
        else if (value is Map) {
          Map<String, dynamic> existingSubMap = Map<String, dynamic>.from(existingMap[key] ?? {});
          Map<String, dynamic> newSubMap = Map<String, dynamic>.from(value);
          
          newSubMap.forEach((subKey, subValue) {
            if (existingSubMap.containsKey(subKey) && subValue is num) {
              existingSubMap[subKey] = (existingSubMap[subKey] ?? 0) + subValue;
            } else {
              existingSubMap[subKey] = subValue;
            }
          });
          
          existingMap[key] = existingSubMap;
        }
        else {
          existingMap[key] = value;
        }
      } else {
        existingMap[key] = value;
      }
    });
    
    existingData[field] = existingMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
       actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Material(
              color: const Color(0xFF4B8673).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Iconsax.calendar,
                    color: const Color(0xFF4B8673),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            isLoading
                ? Center(
                  child: LoadingAnimationWidget.fallingDot(
                    color: const Color(0xFF4b8673),
                    size: 80,
                  ),
                )
                : widget.isAdmin
                ? _buildAdminBody()
                : _buildUserBody(),
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
            Text(
              'No daily summaries yet.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView(
      children:
          allDailyData.entries
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
    
    final int cashTotal = data['cashTotal'] ?? 0;
    final int gcashTotal = data['gcashTotal'] ?? 0;

    // Use data from the specific user card, not class variables
    final int silogCountCard = data['silogCount'] ?? 0;
    final int snackCountCard = data['snackCount'] ?? 0;
    final int regularCupCountCard = data['regularCupCount'] ?? 0;
    final int largeCupCountCard = data['largeCupCount'] ?? 0;

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
            Text(
              username,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('MMMM d, yyyy').format(DateTime.parse(selectedDate)),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              'Total Sales: ₱$totalSales',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Column(
              children: [
                _buildPaymentMethodCard('Cash', cashTotal, Icons.money, Colors.green),
                const SizedBox(height: 10),
                _buildPaymentMethodCard('Gcash', gcashTotal, Icons.phone_android, Colors.blue),
              ],
            ),
            const SizedBox(height: 10),
            
            // Pass the actual counts from data to the category cards
            Row(
              children: [
                Expanded(
                  child: _buildCategoryCard(
                    'Silog',
                    Color(0xffb19985),
                    silogCountCard, // Pass actual count
                    data, // Pass data for dialog
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCategoryCard(
                    'Snacks',
                    Colors.orange,
                    snackCountCard, // Pass actual count
                    data, // Pass data for dialog
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCategoryCard(
                    'Large',
                    Color(0XFF944547),
                    largeCupCountCard, // Pass actual count
                    data, // Pass data for dialog
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCategoryCard(
                    'Regular',
                    Color(0xff7b679a),
                    regularCupCountCard, // Pass actual count
                    data, // Pass data for dialog
                  ),
                ),
              ],
            ),
            if (expenses.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildExpenseCard(expenses, totalExpenses),
            ],
            const SizedBox(height: 10),
            Text(
              'Daily Sales: ₱${netSales.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
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

  Widget _buildPaymentMethodCard(
        String title, int amount, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
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
    
  // Updated _buildCategoryCard to accept count and data parameters
  Widget _buildCategoryCard(String title, Color color, int count, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => _showCategoryDialog(title, color, data),
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
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
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(), // Use the passed count parameter
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
    );
  }

// Update your _showCategoryDialog method to pass the full data
void _showCategoryDialog(String categoryTitle, Color cardColor, Map<String, dynamic> data) async {
  // Show loading dialog
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
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Close loading dialog
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    // Show the actual content dialog - pass the full data instead of just detailed items
    _showContentDialog(categoryTitle, cardColor, data);
    
  } catch (e) {
    // Close loading dialog in case of error
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    // Show error dialog
    _showErrorDialog('Failed to load $categoryTitle details. Please check your internet connection.');
  }
}

// Replace your _showContentDialog method with this updated version
// Alternative version that better matches your data structure
void _showContentDialog(String categoryTitle, Color cardColor, Map<String, dynamic> data) {
  // Get both categories and detailed items
  Map<String, dynamic> categories = {};
  Map<String, dynamic> detailedItems = {};
  
  switch (categoryTitle) {
    case 'Silog':
      categories = Map<String, dynamic>.from(data['silogCategories'] ?? {});
      detailedItems = Map<String, dynamic>.from(data['silogDetailedItems'] ?? {});
      break;
    case 'Snacks':
      categories = Map<String, dynamic>.from(data['snackCategories'] ?? {});
      detailedItems = Map<String, dynamic>.from(data['snackDetailedItems'] ?? {});
      break;
    case 'Regular':
      categories = Map<String, dynamic>.from(data['regularCupCategories'] ?? {});
      detailedItems = Map<String, dynamic>.from(data['regularCupDetailedItems'] ?? {});
      break;
    case 'Large':
      categories = Map<String, dynamic>.from(data['largeCupCategories'] ?? {});
      detailedItems = Map<String, dynamic>.from(data['largeCupDetailedItems'] ?? {});
      break;
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
          child: detailedItems.isEmpty
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
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Item',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 1,
                            child: Text(
                              'Qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
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
                          children: detailedItems.entries.map((entry) {
                            String itemName = entry.key;
                            int quantity = entry.value is int ? entry.value : int.tryParse(entry.value.toString()) ?? 0;
                            
                            // Get the category for this item from categories map
                            String categoryName = categories[itemName]?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: cardColor.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      categoryName.isNotEmpty ? categoryName : '-',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
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

// Error dialog method
void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 24),
          SizedBox(width: 8),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

  Widget _buildExpenseCard(List expenses, double total) {
    return Container(
      decoration: BoxDecoration(
         color: Colors.red.withOpacity(0.05),
         borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
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
                ],
              ),
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
