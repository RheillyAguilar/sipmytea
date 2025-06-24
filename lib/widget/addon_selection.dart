import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:sipmytea/widget/cart_item.dart';
import '../menu_data.dart';
import '../cart_data.dart';

class AddonSelection extends StatefulWidget {
  final Map<String, String> selectedItem;
  final Set<String> selectedAddOns;
  final Function(Set<String>) onAddOnsSelected;

  const AddonSelection({
    super.key,
    required this.selectedItem,
    required this.selectedAddOns,
    required this.onAddOnsSelected,
  });

  @override
  AddonSelectionState createState() => AddonSelectionState();
}

class AddonSelectionState extends State<AddonSelection> {
  late Set<String> _selectedAddOns;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;
  Map<String, int> _addOnStock = {};
  bool _isLoading = true;
  late String _addOnCategory;
  bool _mounted = true;
  List<Map<String, dynamic>> _availablePromos = [];

  @override
  void initState() {
    super.initState();
    // Initialize with empty set instead of using widget.selectedAddOns to fix the persistence issue
    _selectedAddOns = <String>{};
    _addOnCategory = widget.selectedItem['addOnCategory'] ?? 'Add-ons';

    // Check if this is a Silog item and handle it immediately
    String category = widget.selectedItem["category"] ?? "";
    if (category == "Silog") {
      // For Silog items, skip addon selection and go directly to confirmation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onAddOnsSelected(_selectedAddOns);
          _showFinalConfirmationDialog(context, "Ma'am/Sir", "N/A", null);
        }
      });
    } else {
      _loadStock();
      _loadPromos();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  // Helper function to calculate discount amount
  int _calculateDiscountAmount(int originalPrice, String discountText) {
    discountText = discountText.toLowerCase(); // Make case-insensitive

    if (discountText.contains('%')) {
      // Percentage discount (e.g., "10%", "20%")
      String percentageStr = discountText.replaceAll('%', '');
      double percentage = double.tryParse(percentageStr) ?? 0;
      return (originalPrice * (percentage / 100)).round();
    } else if (discountText.contains('₱')) {
      // Fixed amount discount (e.g., "₱50", "₱100")
      String amountStr = discountText.replaceAll('₱', '');
      return int.tryParse(amountStr) ?? 0;
    } else if (discountText.contains('free')) {
      // Free item, full discount
      return originalPrice;
    } else {
      // Try to parse as fixed amount without peso sign
      return int.tryParse(discountText) ?? 0;
    }
  }

  Future<void> _loadPromos() async {
    if (!_mounted) return;

    try {
      QuerySnapshot promoSnapshot = await firestore.collection('promo').get();
      List<Map<String, dynamic>> promos = [];

      for (var doc in promoSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) {
          promos.add({
            'id': doc.id,
            'name': data['name'] ?? '',
            'discounts': data['discounts'] ?? [],
          });
        }
      }

      if (_mounted && mounted) {
        setState(() {
          _availablePromos = promos;
        });
      }
    } catch (e) {
      print('Error loading promos: $e');
    }
  }

  Future<void> _loadStock() async {
    if (!_mounted) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      QuerySnapshot stockSnapshot = await firestore.collection('stock').get();
      Map<String, int> stockMap = {};

      for (var doc in stockSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        stockMap[data['name']] = data['quantity'] ?? 0;
      }

      QuerySnapshot finishedGoodsSnapshot =
          await firestore.collection('finished_goods').get();
      for (var doc in finishedGoodsSnapshot.docs) {
        String docName = doc.id;
        if (docName == 'Creampuff' ||
            docName == 'Pearl' ||
            docName == 'Salted cheese') {
          int quantity = 0;
          var data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('canDo')) {
            quantity = data['canDo'] as int;
          }
          stockMap[docName] = quantity;
        }
      }

      if (_addOnCategory == 'Snack Add-ons') {
        for (var addOn in menuItems['Snack Add-ons'] ?? []) {
          String name = addOn['name'] ?? '';
          if (!stockMap.containsKey(name)) {
            stockMap[name] = 50;
          }
        }
      }

      if (_mounted && mounted) {
        setState(() {
          _addOnStock = stockMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stock: $e');
      if (_mounted && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> printReceipt({
    required String productName,
    required String size,
    required List<String> addOns,
    required String customerName,
    String? sugarLevel,
    String? category,
    int? totalPrice,
  }) async {
    try {
      // Print shop name and header
      printer.printCustom("Sip My Tea", 2, 1);
      printer.printNewLine();

      // Print order information
      String categoryText = category ?? "Beverage";
      printer.printCustom("$categoryText | $productName", 1, 0);

      // Print size and sugar level for beverages
      if (category != "Snack" && category != "Silog") {
        printer.printCustom("$size - ${sugarLevel ?? 'Regular'}", 1, 0);
      }

      // Print add-ons if applicable
      if (addOns.isNotEmpty && category != "Silog") {
        printer.printCustom("Add-ons:", 1, 0);
        for (String addOn in addOns) {
          printer.printCustom("- $addOn", 1, 0);
        }
      } else if (category != "Silog") {
        printer.printCustom("Add-ons: None", 1, 0);
      }

      // Print footer
      printer.printNewLine();
      printer.printCustom("Thank you, $customerName", 1, 0);
      printer.printCustom("Come back soon!", 1, 0);

      // Cut the paper (if supported by printer)
      printer.paperCut();
    } catch (e) {
      debugPrint("Printing failed: $e");
    }
  }

  void _showFinalConfirmationDialog(
    BuildContext context,
    String name,
    String? sugarLevel,
    Map<String, dynamic>? selectedPromo,
  ) {
    if (!mounted) return;

    String productName = widget.selectedItem["name"] ?? "Unknown";
    String category = widget.selectedItem["category"] ?? "";
    String? size = widget.selectedItem["size"];

    int originalPrice;

    if (category == "Snack" || category == "Silog") {
      String basePrice = widget.selectedItem["price"] ?? "₱0";
      originalPrice = int.parse(basePrice.replaceAll("₱", ""));
    } else {
      String sizeKey = (size == "Large") ? "Large" : "Regular";
      String basePrice = widget.selectedItem[sizeKey] ?? "₱0";
      originalPrice = int.parse(basePrice.replaceAll("₱", ""));
    }

    for (String addOn in _selectedAddOns) {
      List<Map<String, String>> addOnsMenu = menuItems[_addOnCategory] ?? [];
      var addOnItem = addOnsMenu.firstWhere(
        (item) => item["name"] == addOn,
        orElse: () => {"price": "₱0"},
      );

      originalPrice += int.parse(addOnItem["price"]!.replaceAll("₱", ""));
    }

    // Calculate discount if promo is selected
    int discountAmount = 0;
    int finalPrice = originalPrice;
    String? promoName;

    if (selectedPromo != null) {
      promoName = selectedPromo['name'];
      String discountText = selectedPromo['selectedDiscount'] ?? '';
      discountAmount = _calculateDiscountAmount(originalPrice, discountText);
      finalPrice = originalPrice - discountAmount;

      // Ensure final price doesn't go below 0
      if (finalPrice < 0) {
        finalPrice = 0;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4B8673), Color(0xFF5A9B85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Order Confirmation",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Product Details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      if (size != null &&
                          size != "N/A" &&
                          category != "Silog" &&
                          (sugarLevel != null &&
                              sugarLevel != 'N/A' &&
                              category != "Snack" &&
                              category != "Silog")) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B8673).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "$size • $sugarLevel",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4B8673),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (_selectedAddOns.isNotEmpty &&
                          category != "Silog") ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Add-ons:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children:
                              _selectedAddOns
                                  .map(
                                    (addOn) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4B8673,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        addOn,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4B8673),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pricing breakdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4B8673).withOpacity(0.1),
                        const Color(0xFF4B8673).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Show subtotal if there's a discount
                      if (discountAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Subtotal:",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            Text(
                              "₱$originalPrice",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Promo ($promoName):",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF38A169),
                              ),
                            ),
                            Text(
                              "-₱$discountAmount",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF38A169),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                      ],
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            "₱$finalPrice",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4B8673),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Thank you message
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Color(0xFFE53E3E),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Thank you $name! Come back soon!",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFE53E3E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _completeOrderWithoutPrinting(
    productName,
    size ?? "N/A",
    sugarLevel,
    category,
    finalPrice,
    originalPrice: originalPrice, // ✅ Pass original price
    discountAmount: discountAmount, // ✅ Pass discount amount
    promoName: promoName, // ✅ Pass promo name
  );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Skip Print",
                          style: TextStyle(
                            color: Color(0xFF718096),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          List<BluetoothDevice> devices =
                              await printer.getBondedDevices();

                          if (devices.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "No printers found. Order confirmed without printing.",
                                  ),
                                ),
                              );
                             // In the printer selection failure ScaffoldMessenger callback:
_completeOrderWithoutPrinting(
  productName,
  size ?? "N/A",
  sugarLevel,
  category,
  finalPrice,
  originalPrice: originalPrice, // ✅ Pass original price
  discountAmount: discountAmount, // ✅ Pass discount amount
  promoName: promoName, // ✅ Pass promo name
);
                            }
                            return;
                          }

                          _showPrinterSelectionDialog(
                            context,
                            devices,
                            productName,
                            size ?? "N/A",
                            sugarLevel,
                            category,
                            finalPrice,
                            name,
                            originalPrice: originalPrice,
                            discountAmount: discountAmount,
                            promoName: promoName,
                          );
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text(
                          "Print Receipt",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B8673),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrinterSelectionDialog(
    BuildContext context,
    List<BluetoothDevice> devices,
    String productName,
    String size,
    String? sugarLevel,
    String category,
    int totalPrice,
    String name, {
    int? originalPrice,
    int? discountAmount,
    String? promoName,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext printerContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4B8673), Color(0xFF5A9B85)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.print, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Select Printer",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(printerContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Printer List
                Flexible(
                  child:
                      devices.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.print_disabled,
                                  size: 48,
                                  color: Color(0xFF718096),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No printers found",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF718096),
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final device = devices[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.print,
                                    color: Color(0xFF4B8673),
                                  ),
                                  title: Text(device.name ?? "Unknown Printer"),
                                  subtitle: Text(device.address ?? ""),
                                  onTap: () async {
                                    Navigator.of(printerContext).pop();

                                    try {
                                      bool? isConnected =
                                          await printer.isConnected;
                                      if (isConnected != true) {
                                        await printer.connect(device);
                                      }

                                      await printReceipt(
                                        productName: productName,
                                        size: size,
                                        addOns: _selectedAddOns.toList(),
                                        customerName: name,
                                        sugarLevel: sugarLevel,
                                        category: category,
                                        totalPrice: totalPrice,
                                      );

                                     _completeOrderWithPrinting(
  productName,
  size,
  sugarLevel,
  category,
  totalPrice,
  originalPrice: originalPrice, // ✅ Pass original price
  discountAmount: discountAmount, // ✅ Pass discount amount
  promoName: promoName, // ✅ Pass promo name
);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Failed to connect: $e",
                                            ),
                                          ),
                                        );
                                        // In the printer connection failure catch block:
_completeOrderWithoutPrinting(
  productName,
  size,
  sugarLevel,
  category,
  totalPrice,
  originalPrice: originalPrice, // ✅ Pass original price
  discountAmount: discountAmount, // ✅ Pass discount amount
  promoName: promoName, // ✅ Pass promo name
);
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// Updated methods to replace in your AddonSelection class

void _completeOrderWithoutPrinting(
  String productName,
  String size,
  String? sugarLevel,
  String category,
  int totalPrice, {
  int? originalPrice,
  int? discountAmount,
  String? promoName,
}) {
  if (!mounted) return;

  cartItems.add(
    CartItem(
      productName: productName,
      size: size,
      addOns: _selectedAddOns.toList(),
      totalPrice: totalPrice,
      category: category,
      sugarLevel: sugarLevel,
      originalPrice: originalPrice, // ✅ Pass original price
      discountAmount: discountAmount, // ✅ Pass discount amount
      promoName: promoName, // ✅ Pass promo name
    ),
  );
  _updateStockInFirestore();

  // Safe navigation with mounted checks
  if (mounted) {
    Navigator.of(context).pop();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

void _completeOrderWithPrinting(
  String productName,
  String size,
  String? sugarLevel,
  String category,
  int totalPrice, {
  int? originalPrice,
  int? discountAmount,
  String? promoName,
}) {
  if (!mounted) return;

  cartItems.add(
    CartItem(
      productName: productName,
      size: size,
      addOns: _selectedAddOns.toList(),
      totalPrice: totalPrice,
      category: category,
      sugarLevel: sugarLevel,
      originalPrice: originalPrice, // ✅ Pass original price
      discountAmount: discountAmount, // ✅ Pass discount amount
      promoName: promoName, // ✅ Pass promo name
    ),
  );
  _updateStockInFirestore();

  // Safe navigation with mounted checks
  if (mounted) {
    Navigator.of(context).pop();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

  Future<void> _updateStockInFirestore() async {
    if (_selectedAddOns.isEmpty) return;

    for (String addOn in _selectedAddOns) {
      if (_addOnCategory == 'Snack Add-ons') {
        print('Snack add-on "$addOn" used - stock tracking skipped');
        continue;
      }

      if (addOn == 'Creampuff' ||
          addOn == 'Pearl' ||
          addOn == 'Salted cheese') {
        try {
          DocumentSnapshot doc =
              await firestore.collection('finished_goods').doc(addOn).get();
          if (doc.exists) {
            var data = doc.data() as Map<String, dynamic>;
            int currentQuantity = data['quantity'] ?? 0;
            if (currentQuantity > 0) {
              await firestore.collection('finished_goods').doc(addOn).update({
                'quantity': currentQuantity - 1,
              });
            }
          }
        } catch (e) {
          print('Error updating stock for $addOn: $e');
        }
      } else {
        try {
          QuerySnapshot querySnapshot =
              await firestore
                  .collection('stock')
                  .where('name', isEqualTo: addOn)
                  .get();
          if (querySnapshot.docs.isNotEmpty) {
            DocumentSnapshot doc = querySnapshot.docs.first;
            int currentQuantity =
                (doc.data() as Map<String, dynamic>)['quantity'] ?? 0;
            if (currentQuantity > 0) {
              await firestore.collection('stock').doc(doc.id).update({
                'quantity': currentQuantity - 1,
              });
            }
          }
        } catch (e) {
          print('Error updating stock for $addOn: $e');
        }
      }
    }

    if (_mounted && mounted) {
      _loadStock();
    }
  }

  void _handleConfirmation() {
    if (!mounted) return;

    String category = widget.selectedItem["category"] ?? "";

    if (category == "Snack" || category == "Silog") {
      // For Snack and Silog items, proceed directly to final confirmation with default name
      _showFinalConfirmationDialog(context, "Ma'am/Sir", "N/A", null);
    } else {
      // For drinks, show sugar level selection
      _showSugarLevelDialog(context);
    }
  }

  void _showSugarLevelDialog(BuildContext context) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4B8673), Color(0xFF5A9B85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Sugar Level",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "Choose your sweetness preference",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Sugar Level Grid
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildSugarLevelCard(
                          "100%",
                          Icons.sentiment_very_satisfied,
                          const Color(0xFFE53E3E),
                        ),
                        _buildSugarLevelCard(
                          "75%",
                          Icons.sentiment_satisfied,
                          const Color(0xFFED8936),
                        ),
                        _buildSugarLevelCard(
                          "50%",
                          Icons.sentiment_neutral,
                          const Color(0xFF4B8673),
                        ), // Changed this line
                        _buildSugarLevelCard(
                          "25%",
                          Icons.sentiment_dissatisfied,
                          const Color(0xFF3182CE),
                        ),
                        _buildSugarLevelCard(
                          "0%",
                          Icons.sentiment_very_dissatisfied,
                          const Color(0xFF718096),
                        ),
                        _buildSugarLevelCard(
                          "Custom",
                          Icons.tune,
                          const Color(0xFF805AD5),
                        ), // Added custom option
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSugarLevelCard(String level, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        _showCustomerNameDialog(context, level);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 8),
            Text(
              level,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerNameDialog(BuildContext context, String sugarLevel) {
    if (!mounted) return;

    TextEditingController nameController = TextEditingController();
    Map<String, dynamic>? selectedPromo;
    String? selectedDiscount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: _availablePromos.isEmpty ? 400 : 700,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4B8673), Color(0xFF5A9B85)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Customer Details",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer Name Input
                            const Text(
                              "Customer Name",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                hintText: "Enter customer name",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF4B8673),
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Promo Selection
                            if (_availablePromos.isNotEmpty) ...[
                              const Text(
                                "Available Promos",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          // No Promo Option
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                selectedPromo = null;
                                              });
                                            },
                                            child: Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color:
                                                    selectedPromo == null
                                                        ? const Color(
                                                          0xFF4B8673,
                                                        ).withOpacity(0.1)
                                                        : Colors.white,
                                                border: Border.all(
                                                  color:
                                                      selectedPromo == null
                                                          ? const Color(
                                                            0xFF4B8673,
                                                          )
                                                          : const Color(
                                                            0xFFE2E8F0,
                                                          ),
                                                  width: 2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                "No Promo",
                                                style: TextStyle(
                                                  color:
                                                      selectedPromo == null
                                                          ? const Color(
                                                            0xFF4B8673,
                                                          )
                                                          : const Color(
                                                            0xFF4A5568,
                                                          ),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Available Promos
                                          ..._availablePromos.map((promo) {
                                            List<dynamic> discounts =
                                                promo['discounts'] ?? [];
                                            return Column(
                                              children:
                                                  discounts.map<Widget>((
                                                    discount,
                                                  ) {
                                                    String discountText =
                                                        discount.toString();
                                                    bool isSelected =
                                                        selectedPromo != null &&
                                                        selectedPromo!['id'] ==
                                                            promo['id'] &&
                                                        selectedPromo!['selectedDiscount'] ==
                                                            discountText;

                                                    return GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          selectedPromo = {
                                                            'id': promo['id'],
                                                            'name':
                                                                promo['name'],
                                                            'selectedDiscount':
                                                                discountText,
                                                          };
                                                        });
                                                      },
                                                      child: Container(
                                                        width: double.infinity,
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isSelected
                                                                  ? const Color(
                                                                    0xFF38A169,
                                                                  ).withOpacity(
                                                                    0.1,
                                                                  )
                                                                  : Colors
                                                                      .white,
                                                          border: Border.all(
                                                            color:
                                                                isSelected
                                                                    ? const Color(
                                                                      0xFF38A169,
                                                                    )
                                                                    : const Color(
                                                                      0xFFE2E8F0,
                                                                    ),
                                                            width: 2,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.local_offer,
                                                              color:
                                                                  isSelected
                                                                      ? const Color(
                                                                        0xFF38A169,
                                                                      )
                                                                      : const Color(
                                                                        0xFF718096,
                                                                      ),
                                                              size: 16,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                "${promo['name']} - $discountText",
                                                                style: TextStyle(
                                                                  color:
                                                                      isSelected
                                                                          ? const Color(
                                                                            0xFF38A169,
                                                                          )
                                                                          : const Color(
                                                                            0xFF4A5568,
                                                                          ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _showFinalConfirmationDialog(
                                        context,
                                        "Ma'am/Sir",
                                        sugarLevel,
                                        selectedPromo
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "Skip Name",
                                      style: TextStyle(
                                        color: Color(0xFF718096),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      String customerName =
                                          nameController.text.trim();
                                      if (customerName.isEmpty)
                                        customerName = "Ma'am/Sir";
                                      Navigator.of(context).pop();
                                      _showFinalConfirmationDialog(
                                        context,
                                        customerName,
                                        sugarLevel,
                                        selectedPromo
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4B8673),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Confirm",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String category = widget.selectedItem["category"] ?? "";

    // Handle Silog items - don't show addon selection UI
    if (category == "Silog") {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B8673)),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Add-ons"),
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C3E50)),
          ),
        ),
        body: Center(
          child: LoadingAnimationWidget.threeArchedCircle(
            color: const Color(0xFF4B8673),
            size: 50,
          ),
        ),
      );
    }

    List<Map<String, String>> addOnsMenu = menuItems[_addOnCategory] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_addOnCategory),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C3E50)),
        ),
        actions: [
          if (_selectedAddOns.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_selectedAddOns.length} selected",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected Item Info
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedItem["name"] ?? "Unknown Item",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (widget.selectedItem["size"] != null &&
                    widget.selectedItem["size"] != "N/A") ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B8673).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.selectedItem["size"]!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B8673),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Add-ons List
          Expanded(
            child:
                addOnsMenu.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 64,
                            color: Color(0xFF718096),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No add-ons available",
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF718096),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: addOnsMenu.length,
                      itemBuilder: (context, index) {
                        var addOn = addOnsMenu[index];
                        String name = addOn["name"] ?? "";
                        String price = addOn["price"] ?? "₱0";
                        bool isSelected = _selectedAddOns.contains(name);
                        int stock = _addOnStock[name] ?? 0;
                        bool isAvailable =
                            stock > 0 || _addOnCategory == 'Snack Add-ons';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap:
                                  isAvailable
                                      ? () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedAddOns.remove(name);
                                          } else {
                                            _selectedAddOns.add(name);
                                          }
                                        });
                                        widget.onAddOnsSelected(
                                          _selectedAddOns,
                                        );
                                      }
                                      : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? const Color(
                                            0xFF4B8673,
                                          ).withOpacity(0.1)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? const Color(0xFF4B8673)
                                            : isAvailable
                                            ? const Color(0xFFE2E8F0)
                                            : const Color(0xFFE53E3E),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Selection Indicator
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            isSelected
                                                ? const Color(0xFF4B8673)
                                                : Colors.transparent,
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? const Color(0xFF4B8673)
                                                  : const Color(0xFFCBD5E0),
                                          width: 2,
                                        ),
                                      ),
                                      child:
                                          isSelected
                                              ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                              : null,
                                    ),
                                    const SizedBox(width: 16),

                                    // Add-on Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isAvailable
                                                      ? const Color(0xFF2D3748)
                                                      : const Color(0xFF718096),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                price,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      isAvailable
                                                          ? const Color(
                                                            0xFF4B8673,
                                                          )
                                                          : const Color(
                                                            0xFF718096,
                                                          ),
                                                ),
                                              ),
                                              if (!isAvailable) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFE53E3E,
                                                    ).withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    "Out of Stock",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFFE53E3E),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ] else if (_addOnCategory !=
                                                  'Snack Add-ons') ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Stock: $stock",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF718096),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B8673),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _selectedAddOns.isEmpty
                        ? "Continue without Add-ons"
                        : "Continue with ${_selectedAddOns.length} Add-on${_selectedAddOns.length > 1 ? 's' : ''}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}