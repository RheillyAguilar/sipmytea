// ignore_for_file: use_build_context_synchronously, deprecated_member_use
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
    widget.isAdmin ? await _loadAllUsersDailyData() : await _loadUserDailyData();
  }

  Future<void> _loadUserDailyData() async {
    final doc = await firestore
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
                Text('Are you sure you want to add this to the Monthly Sale?', style: TextStyle(fontSize: 15),)
              ],
            ),
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
    // Extract counts from the current data
    final int totalSales = data['totalSales'] ?? 0;
    final int netSales = data['netSales'] ?? 0;
    
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
                Expanded(child: _buildCategoryCard('Silog', Colors.blue, silogCountCard)),
                const SizedBox(width: 10),
                Expanded(child: _buildCategoryCard('Snacks', Colors.orange, snackCountCard)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildCategoryCard('Large Cup', Colors.green, largeCupCountCard)),
                const SizedBox(width: 10),
                Expanded(child: _buildCategoryCard('Regular Cup', Colors.red, regularCupCountCard)),
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


  Widget _buildCategoryCard(String title, Color color, int count) {
    return InkWell( // Changed from GestureDetector to InkWell for better tap feedback
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
  final Future<QuerySnapshot> query = firestore
      .collection('daily_records')
      .doc(selectedDate)
      .collection('users')
      .get();

  // Use a loading indicator while fetching data
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  query.then((snapshot) {
    // Close the loading dialog
    Navigator.pop(context);
    
    if (snapshot.docs.isEmpty) {
      // Show message if no data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      
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
      if (useSubcategories && categoriesFieldName.isNotEmpty && 
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
                  (subcategoryItems[subcategory]![itemName] ?? 0) + itemCount;
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '$categoryTitle Breakdown', 
          style: const TextStyle(
            fontSize: 17, 
            fontWeight: FontWeight.bold, 
            fontStyle: FontStyle.italic
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: subcategoryItems.isEmpty
            ? const Center(child: Text('No detailed data available.'))
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

                  for (var subcategoryEntry in subcategoryItems.entries) {
                    String subcategory = subcategoryEntry.key;
                    Map<String, int> items = subcategoryEntry.value;

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

                  if (currentSubcategory == null || currentItem == null) {
                    return const SizedBox.shrink();
                  }

                  // Clean the item name to remove parentheses
                  String displayName = _cleanItemName(currentItem.key);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                            if (currentSubcategory.isNotEmpty) ...[
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
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontSize: 14),
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
                                borderRadius: BorderRadius.circular(16),
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
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }).catchError((error) {
    // Close the loading dialog if there's an error
    Navigator.pop(context);
    
    // Show error dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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