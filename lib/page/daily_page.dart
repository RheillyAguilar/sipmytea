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
  bool isLoading = true; // Add a loading state variable

  // These variables need to be initialized in the widget scope to access them everywhere
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
      isLoading = true; // Set loading to true when starting data fetch
    });

    try {
      widget.isAdmin
          ? await _loadAllUsersDailyData()
          : await _loadUserDailyData();
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      // Ensure loading is set to false even if there's an error
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
      // Update count variables when data is loaded
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

  // Show loading indicator while processing
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

    // Handle expenses data properly
    Map<String, dynamic> formattedExpenses = {};
    final dynamic expensesData = data['expenses'];
    
    if (expensesData != null) {
      // Handle if expenses is already a Map
      if (expensesData is Map) {
        formattedExpenses = Map<String, dynamic>.from(expensesData);
      } 
      // Handle if expenses is a List
      else if (expensesData is List && expensesData.isNotEmpty) {
        // Convert list to map with numeric keys
        for (int i = 0; i < expensesData.length; i++) {
          formattedExpenses[i.toString()] = expensesData[i];
        }
      }
      
      // Debug info
      print('Expenses data type: ${expensesData.runtimeType}');
      print('Formatted expenses: $formattedExpenses');
    }

    // Create a complete user detail entry
    Map<String, dynamic> userDetailEntry = {
      'username': username,
      'amount': netSales,
      'totalSales': data['totalSales'] ?? 0,
      'netSales': netSales,
      'cashTotal': cashTotal,
      'gcashTotal': gcashTotal,
      'date': selectedDate,
      'formattedDate': formattedDate,

      // Product counts
      'silogCount': data['silogCount'] ?? 0,
      'snackCount': data['snackCount'] ?? 0,
      'regularCupCount': data['regularCupCount'] ?? 0,
      'largeCupCount': data['largeCupCount'] ?? 0,

      // Detailed categories and items
      'silogCategories': data['silogCategories'] ?? {},
      'silogDetailedItems': data['silogDetailedItems'] ?? {},
      'snackCategories': data['snackCategories'] ?? {},
      'snackDetailedItems': data['snackDetailedItems'] ?? {},
      'regularCupCategories': data['regularCupCategories'] ?? {},
      'regularCupDetailedItems': data['regularCupDetailedItems'] ?? {},
      'largeCupCategories': data['largeCupCategories'] ?? {},
      'largeCupDetailedItems': data['largeCupDetailedItems'] ?? {},
    };

    // Add expenses if they exist
    if (formattedExpenses.isNotEmpty) {
      userDetailEntry['expenses'] = formattedExpenses;
    }

    // Reference to the monthly sales document
    final docRef = firestore.collection('monthly_sales').doc(formattedDate);
    final docSnap = await docRef.get();

    // Create a batch to ensure all operations complete or none do
    final batch = firestore.batch();

    if (docSnap.exists) {
      // Get existing data
      final Map<String, dynamic> existingData = docSnap.data() ?? {};
      final List<dynamic> existingUsers = existingData['users'] ?? [];
      final List<dynamic> existingUserDetails = existingData['userDetails'] ?? [];
      final Map<String, dynamic> existingMonthData = existingData['monthData'] ?? {};
      
      // Calculate updated month totals including cash and gcash
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

      // Check if this user already exists in the monthly data
      int existingUserIndex = -1;
      for (int i = 0; i < existingUserDetails.length; i++) {
        if (existingUserDetails[i]['username'] == username) {
          existingUserIndex = i;
          break;
        }
      }

      if (existingUserIndex >= 0) {
        // User already exists - update their data by merging the new sales with existing
        final Map<String, dynamic> existingUserData = Map<String, dynamic>.from(existingUserDetails[existingUserIndex]);
        
        // Update basic counts and totals
        existingUserData['amount'] = (existingUserData['amount'] ?? 0) + netSales;
        existingUserData['totalSales'] = (existingUserData['totalSales'] ?? 0) + (data['totalSales'] ?? 0);
        existingUserData['netSales'] = (existingUserData['netSales'] ?? 0) + netSales;
        existingUserData['cashTotal'] = (existingUserData['cashTotal'] ?? 0) + cashTotal;
        existingUserData['gcashTotal'] = (existingUserData['gcashTotal'] ?? 0) + gcashTotal;
        
        // Update product counts
        existingUserData['silogCount'] = (existingUserData['silogCount'] ?? 0) + (data['silogCount'] ?? 0);
        existingUserData['snackCount'] = (existingUserData['snackCount'] ?? 0) + (data['snackCount'] ?? 0);
        existingUserData['regularCupCount'] = (existingUserData['regularCupCount'] ?? 0) + (data['regularCupCount'] ?? 0);
        existingUserData['largeCupCount'] = (existingUserData['largeCupCount'] ?? 0) + (data['largeCupCount'] ?? 0);
        
        // Update detailed categories by merging
        _mergeDetailedData(existingUserData, data, 'silogCategories');
        _mergeDetailedData(existingUserData, data, 'silogDetailedItems');
        _mergeDetailedData(existingUserData, data, 'snackCategories');
        _mergeDetailedData(existingUserData, data, 'snackDetailedItems');
        _mergeDetailedData(existingUserData, data, 'regularCupCategories');
        _mergeDetailedData(existingUserData, data, 'regularCupDetailedItems');
        _mergeDetailedData(existingUserData, data, 'largeCupCategories');
        _mergeDetailedData(existingUserData, data, 'largeCupDetailedItems');
        
        // Update expenses
        if (formattedExpenses.isNotEmpty) {
          Map<String, dynamic> existingExpenses = Map<String, dynamic>.from(existingUserData['expenses'] ?? {});
          
          // For each expense in the new data, add it to existing expenses
          formattedExpenses.forEach((key, value) {
            String uniqueKey = '${existingExpenses.length}_${DateTime.now().millisecondsSinceEpoch}';
            existingExpenses[uniqueKey] = value;
          });
          
          existingUserData['expenses'] = existingExpenses;
        }
        
        // Update the user data in the list
        existingUserDetails[existingUserIndex] = existingUserData;
      } else {
        // User doesn't exist yet - add to users list and add details
        existingUsers.add(username);
        existingUserDetails.add(userDetailEntry);
      }

      // Update the document with all merged data
      batch.update(docRef, {
        'amount': FieldValue.increment(netSales),
        'users': existingUsers,
        'userDetails': existingUserDetails,
        'monthData': updatedMonthData,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new document with all details including cash and gcash totals
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

    // Delete the daily record
    final dailyRecordRef = firestore
        .collection('daily_records')
        .doc(selectedDate)
        .collection('users')
        .doc(username);
    batch.delete(dailyRecordRef);

    // Commit the batch
    await batch.commit();

    // Update local data
    setState(() => allDailyData.remove(username));

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Successfully added to monthly sales'),
      ),
    );

    // Close loading dialog
    Navigator.pop(context);
  } catch (e) {
    // Close loading dialog
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

// Helper function to merge detailed map data
void _mergeDetailedData(Map<String, dynamic> existingData, Map<String, dynamic> newData, String field) {
  Map<String, dynamic> existingMap = Map<String, dynamic>.from(existingData[field] ?? {});
  Map<String, dynamic> newMap = Map<String, dynamic>.from(newData[field] ?? {});
  
  newMap.forEach((key, value) {
    if (existingMap.containsKey(key)) {
      // If the value is numeric, add them
      if (value is num) {
        existingMap[key] = (existingMap[key] ?? 0) + value;
      } 
      // If the value is a map, recursively merge
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
      // Otherwise just overwrite (last one wins)
      else {
        existingMap[key] = value;
      }
    } else {
      // Key doesn't exist yet, just add it
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
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
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
  // Extract counts from the current data
  final int totalSales = data['totalSales'] ?? 0;
  final int netSales = data['netSales'] ?? 0;
  
  // Extract cash and GCash totals
  final int cashTotal = data['cashTotal'] ?? 0;
  final int gcashTotal = data['gcashTotal'] ?? 0;

  // Set these variables for use in the category cards
  int silogCountCard = data['silogCount'] ?? 0;
  int snackCountCard = data['snackCount'] ?? 0;
  int regularCupCountCard = data['regularCupCount'] ?? 0;
  int largeCupCountCard = data['largeCupCount'] ?? 0;

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
          
          // Cash and GCash Display
          Row(
            children: [
              Expanded(
                child: _buildPaymentMethodCard('Cash', cashTotal, Icons.money, Colors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPaymentMethodCard('Gcash', gcashTotal, Icons.phone_android, Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Silog',
                  Color(0xffb19985),
                  silogCountCard,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryCard(
                  'Snacks',
                  Colors.orange,
                  snackCountCard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Large Cup',
                  Color(0XFF944547),
                  largeCupCountCard,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryCard(
                  'Regular Cup',
                  Color(0xff7b679a),
                  regularCupCountCard,
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

// Add this new method to build payment method cards
Widget _buildPaymentMethodCard(String title, int amount, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12.0),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₱$amount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _buildCategoryCard(String title, Color color, int count) {
    return InkWell(
      // Changed from GestureDetector to InkWell for better tap feedback
      onTap: () => _showCategoryDialog(title, color),
      child: Card(
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
      ),
    );
  }

  void _showCategoryDialog(String categoryTitle, Color cardColor) {
    // Create a map to store the counts for each item in the selected category
    Map<String, Map<String, int>> subcategoryItems = {};

    // Get the appropriate document - user or all users
    final Future<QuerySnapshot> query =
        firestore
            .collection('daily_records')
            .doc(selectedDate)
            .collection('users')
            .get();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
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

    query
        .then((snapshot) {
          // Close the loading dialog
          Navigator.pop(context);

          if (snapshot.docs.isEmpty) {
            // Show message if no data
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text('$categoryTitle Breakdown'),
                    content: const SizedBox(
                      height: 150, // Fixed height for empty state
                      child: Center(
                        child: Text('No data available for this category.'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
            );
            return;
          }

          // Process each user's data
          for (var userDoc in snapshot.docs) {
            // Filter by username if not admin
            if (!widget.isAdmin && userDoc.id != widget.username) {
              continue;
            }

            // Extract data
            Map<String, dynamic>? userData =
                userDoc.data() as Map<String, dynamic>?;

            if (userData == null) continue;

            // Determine fields based on category
            String countFieldName = '';
            String categoriesFieldName = '';
            String detailedItemsFieldName = '';
            bool useSubcategories = false;

            if (categoryTitle == 'Silog') {
              countFieldName = 'silogCount';
              categoriesFieldName = 'silogCategories';
              detailedItemsFieldName = 'silogDetailedItems';
              useSubcategories = false;
            } else if (categoryTitle == 'Snacks') {
              countFieldName = 'snackCount';
              categoriesFieldName = 'snackCategories';
              detailedItemsFieldName = 'snackDetailedItems';
              useSubcategories = false;
            } else if (categoryTitle == 'Regular Cup') {
              countFieldName = 'regularCupCount';
              categoriesFieldName = 'regularCupCategories';
              detailedItemsFieldName = 'regularCupDetailedItems';
              useSubcategories = true;
            } else if (categoryTitle == 'Large Cup') {
              countFieldName = 'largeCupCount';
              categoriesFieldName = 'largeCupCategories';
              detailedItemsFieldName = 'largeCupDetailedItems';
              useSubcategories = true;
            }

            // Skip if no count field found
            if (!userData.containsKey(countFieldName)) continue;

            // Get subcategory information
            Map<String, String> itemToSubcategory = {};
            if (useSubcategories &&
                categoriesFieldName.isNotEmpty &&
                userData.containsKey(categoriesFieldName)) {
              var categories = userData[categoriesFieldName];
              if (categories is Map) {
                categories.forEach((key, value) {
                  if (key is String && value is String) {
                    itemToSubcategory[key] = value;
                  }
                });
              }
            }

            // Check for detailed items first (since they have the full information)
            if (userData.containsKey(detailedItemsFieldName)) {
              var detailedItems = userData[detailedItemsFieldName];
              if (detailedItems is Map) {
                detailedItems.forEach((itemName, count) {
                  if (itemName is String) {
                    int itemCount = 1;
                    if (count is int) {
                      itemCount = count;
                    } else if (count is String) {
                      itemCount = int.tryParse(count) ?? 1;
                    }

                    String subcategory = itemToSubcategory[itemName] ?? '';

                    // Add the detailed item with its count
                    if (!subcategoryItems.containsKey(subcategory)) {
                      subcategoryItems[subcategory] = {};
                    }
                    subcategoryItems[subcategory]![itemName] =
                        (subcategoryItems[subcategory]![itemName] ?? 0) +
                        itemCount;
                  }
                });
              }
            }
          }

          // Create color variants for UI
          Color badgeBackgroundColor = cardColor.withOpacity(0.3);
          Color badgeTextColor = cardColor.withOpacity(0.9);

          // Show the dialog with the data
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(
                    '$categoryTitle Breakdown',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child:
                        subcategoryItems.isEmpty
                            ? const Center(
                              child: Text('No detailed data available.'),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: subcategoryItems.entries.fold(
                                0,
                                (sum, entry) => sum! + entry.value.length,
                              ),
                              itemBuilder: (context, index) {
                                // Find the correct subcategory and item for this index
                                int itemsFound = 0;
                                String? currentSubcategory;
                                MapEntry<String, int>? currentItem;

                                for (var subcategoryEntry
                                    in subcategoryItems.entries) {
                                  String subcategory = subcategoryEntry.key;
                                  Map<String, int> items =
                                      subcategoryEntry.value;

                                  if (index < itemsFound + items.length) {
                                    // This index belongs to this subcategory
                                    currentSubcategory = subcategory;
                                    currentItem = items.entries.elementAt(
                                      index - itemsFound,
                                    );
                                    break;
                                  }

                                  itemsFound += items.length;
                                }

                                if (currentSubcategory == null ||
                                    currentItem == null) {
                                  return const SizedBox.shrink();
                                }

                                // Clean the item name to remove parentheses
                                String displayName = _cleanItemName(
                                  currentItem.key,
                                );

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 16.0,
                                      ),
                                      child: Row(
                                        children: [
                                          // Only show subcategory if it's not empty
                                          if (currentSubcategory
                                              .isNotEmpty) ...[
                                            // Subcategory column
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                currentSubcategory,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            // Separator
                                            Container(
                                              width: 1,
                                              height: 24,
                                              color: Colors.grey.shade700,
                                            ),
                                          ],
                                          // Name column - using cleaned display name
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 16.0,
                                              ),
                                              child: Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Count with color matching the card
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0,
                                              vertical: 4.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeBackgroundColor,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              '${currentItem.value}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: badgeTextColor,
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
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          );
        })
        .catchError((error) {
          // Close the loading dialog if there's an error
          Navigator.pop(context);

          // Show error dialog
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Error'),
                  content: Text('Failed to load data: $error'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          );
        });
  }

  // Helper method to clean item names by removing parentheses
  String _cleanItemName(String itemName) {
    // If the item name contains parentheses, take only the part before it
    int indexOfParenthesis = itemName.indexOf('(');
    if (indexOfParenthesis > 0) {
      return itemName.substring(0, indexOfParenthesis).trim();
    }
    return itemName;
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
              'Total Expenses: ₱$total',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
