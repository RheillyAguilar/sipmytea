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

  @override
  void initState() {
    super.initState();
    _selectedAddOns = Set.from(widget.selectedAddOns);
    _addOnCategory = widget.selectedItem['addOnCategory'] ?? 'Add-ons';
    
    // Check if this is a Silog item and handle it immediately
    String category = widget.selectedItem["category"] ?? "";
    if (category == "Silog") {
      // For Silog items, skip addon selection and go directly to confirmation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAddOnsSelected(_selectedAddOns);
        _showFinalConfirmationDialog(context, "Customer", "N/A");
      });
    } else {
      _loadStock();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _loadStock() async {
    if (!_mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot stockSnapshot = await firestore.collection('stock').get();
      Map<String, int> stockMap = {};

      for (var doc in stockSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        stockMap[data['name']] = data['quantity'] ?? 0;
      }

      QuerySnapshot finishedGoodsSnapshot = await firestore.collection('finished_goods').get();
      for (var doc in finishedGoodsSnapshot.docs) {
        String docName = doc.id;
        if (docName == 'Creampuff' || docName == 'Pearl' || docName == 'Salted cheese') {
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

      if (_mounted) {
        setState(() {
          _addOnStock = stockMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stock: $e');
      if (_mounted) {
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
    printer.printCustom("Please buy again", 1, 0);
    
    // Cut the paper (if supported by printer)
    printer.paperCut();
  } catch (e) {
    debugPrint("Printing failed: $e");
  }
}

  void _showFinalConfirmationDialog(BuildContext context, String name, String? sugarLevel) {
    String productName = widget.selectedItem["name"] ?? "Unknown";
    String category = widget.selectedItem["category"] ?? "";
    String? size = widget.selectedItem["size"];

    int totalPrice;

    if (category == "Snack" || category == "Silog") {
      String basePrice = widget.selectedItem["price"] ?? "₱0";
      totalPrice = int.parse(basePrice.replaceAll("₱", ""));
    } else {
      String sizeKey = (size == "Large") ? "Large" : "Regular";
      String basePrice = widget.selectedItem[sizeKey] ?? "₱0";
      totalPrice = int.parse(basePrice.replaceAll("₱", ""));
    }

    for (String addOn in _selectedAddOns) {
      List<Map<String, String>> addOnsMenu = menuItems[_addOnCategory] ?? [];
      var addOnItem = addOnsMenu.firstWhere(
        (item) => item["name"] == addOn,
        orElse: () => {"price": "₱0"},
      );

      totalPrice += int.parse(addOnItem["price"]!.replaceAll("₱", ""));
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Order Confirmation",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text("$productName", style: const TextStyle(fontSize: 18)),
                if (size != null && size != "N/A" && category != "Silog" && (sugarLevel != null && sugarLevel != 'N/A' && category != "Snack" && category != "Silog"))
                  Text("$size | $sugarLevel", style: const TextStyle(fontSize: 18)),
                if (_selectedAddOns.isNotEmpty && category != "Silog") ...[
                  const SizedBox(height: 10),
                  const Text(
                    "Add-ons:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (String addOn in _selectedAddOns)
                    Text("- $addOn", style: const TextStyle(fontSize: 16)),
                ],
                const SizedBox(height: 12),
                Text(
                  "Total Price: ₱$totalPrice",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 12),
                Text(
                  "Thank you $name, please buy again!",
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        List<BluetoothDevice> devices = await printer.getBondedDevices();

                        if (devices.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No printers found. Order confirmed without printing.")),
                          );
                          _completeOrderWithoutPrinting(productName, size ?? "N/A", sugarLevel, category, totalPrice);
                          return;
                        }

                        showDialog(
                          context: context,
                          builder: (BuildContext printerContext) {
                            return AlertDialog(
                              title: const Text("Select Printer"),
                              content: SizedBox(
                                height: 300,
                                width: 300,
                                child: ListView.builder(
                                  itemCount: devices.length,
                                  itemBuilder: (context, index) {
                                    final device = devices[index];
                                    return ListTile(
                                      title: Text(device.name ?? "Unknown"),
                                      subtitle: Text(device.address ?? ""),
                                      onTap: () async {
                                        Navigator.of(printerContext).pop();

                                        bool? isConnected = await printer.isConnected;

                                        try {
                                          if (isConnected != true) {
                                            await printer.connect(device);
                                          }

                                          await printReceipt(
                                            productName: productName,
                                            size: size ?? "N/A",
                                            addOns: _selectedAddOns.toList(),
                                            customerName: name,
                                            sugarLevel: sugarLevel,
                                            category: category,
                                            totalPrice: totalPrice,
                                          );

                                          _completeOrderWithPrinting(productName, size ?? "N/A", sugarLevel, category, totalPrice);
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Failed to connect: $e"),
                                            ),
                                          );
                                          _completeOrderWithoutPrinting(productName, size ?? "N/A", sugarLevel, category, totalPrice);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4B8673),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide.none
                        )
                      ),
                      child: const Text("Print Receipt", style: TextStyle(color: Colors.white),),
                    ),
                    TextButton(
                      onPressed: () {
                        _completeOrderWithoutPrinting(productName, size ?? "N/A", sugarLevel, category, totalPrice);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700]
                      ),
                      child: const Text("Without Printing"),
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

  void _completeOrderWithoutPrinting(String productName, String size, String? sugarLevel, String category, int totalPrice) {
    cartItems.add(
      CartItem(
        productName: productName,
        size: size,
        addOns: _selectedAddOns.toList(),
        totalPrice: totalPrice,
        category: category,
        sugarLevel: sugarLevel,
      ),
    );
    _updateStockInFirestore();
    Navigator.of(context).pop();
    Navigator.of(this.context).pop();
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(content: Text("Order added!")),
    );
  }

  void _completeOrderWithPrinting(String productName, String size, String? sugarLevel, String category, int totalPrice) {
    cartItems.add(
      CartItem(
        productName: productName,
        size: size,
        addOns: _selectedAddOns.toList(),
        totalPrice: totalPrice,
        category: category,
        sugarLevel: sugarLevel,
      ),
    );
    _updateStockInFirestore();
    Navigator.of(context).pop();
    Navigator.of(this.context).pop();
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(content: Text("Order added and printed!")),
    );
  }

  Future<void> _updateStockInFirestore() async {
    if (_selectedAddOns.isEmpty) return;

    for (String addOn in _selectedAddOns) {
      if (_addOnCategory == 'Snack Add-ons') {
        print('Snack add-on "$addOn" used - stock tracking skipped');
        continue;
      }

      if (addOn == 'Creampuff' || addOn == 'Pearl' || addOn == 'Salted cheese') {
        try {
          DocumentSnapshot doc = await firestore.collection('finished_goods').doc(addOn).get();
          if (doc.exists) {
            var data = doc.data() as Map<String, dynamic>;
            int currentQuantity = data['quantity'] ?? 0;
            if (currentQuantity > 0) {
              await firestore.collection('finished_goods').doc(addOn).update({'quantity': currentQuantity - 1});
            }
          }
        } catch (e) {
          print('Error updating stock for $addOn: $e');
        }
      } else {
        try {
          QuerySnapshot querySnapshot = await firestore.collection('stock').where('name', isEqualTo: addOn).get();
          if (querySnapshot.docs.isNotEmpty) {
            DocumentSnapshot doc = querySnapshot.docs.first;
            int currentQuantity = (doc.data() as Map<String, dynamic>)['quantity'] ?? 0;
            if (currentQuantity > 0) {
              await firestore.collection('stock').doc(doc.id).update({'quantity': currentQuantity - 1});
            }
          }
        } catch (e) {
          print('Error updating stock for $addOn: $e');
        }
      }
    }

    if (_mounted) {
      _loadStock();
    }
  }

  void _handleConfirmation() {
    String category = widget.selectedItem["category"] ?? "";
    
    if (category == "Snack" || category == "Silog") {
      // For Snack and Silog items, proceed directly to final confirmation with default name
      _showFinalConfirmationDialog(context, "Customer", "N/A");
    } else {
      // For drinks, show sugar level selection
      _showSugarLevelDialog(context);
    }
  }

  void _showSugarLevelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Select Sugar Level", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildSugarOption(context, "No Sugar"),
                _buildSugarOption(context, "25%"),
                _buildSugarOption(context, "50%"),
                _buildSugarOption(context, "75%"),
                _buildSugarOption(context, "100%"),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSugarOption(BuildContext context, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        _promptForNameWithSugarLevel(label);
      },
    );
  }

  void _promptForNameWithSugarLevel(String sugarLevel) {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Enter Customer Name",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Name",
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please input a name"),
                            ),
                          );
                        } else {
                          Navigator.of(context).pop();
                          String rawName = nameController.text.trim();
                          String capitalized =
                              rawName[0].toUpperCase() + rawName.substring(1);
                          _showFinalConfirmationDialog(context, capitalized, sugarLevel);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B8673),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)
                        )
                      ),
                      child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700]
                      ),
                      child: const Text("Cancel"),
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

  @override
  Widget build(BuildContext context) {
    String category = widget.selectedItem["category"] ?? "";
    
    // For Silog items, show a loading indicator while the confirmation dialog is being prepared
    if (category == "Silog") {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4B8673),
          ),
        ),
      );
    }
    
    String dialogTitle = _addOnCategory == "Snack Add-ons" ? "Select Snack Add-ons" : "Select Add-ons";
    List<Map<String, String>> addOnsList = menuItems[_addOnCategory] ?? [];

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dialogTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 10),
            _isLoading
                ? Center(child: LoadingAnimationWidget.fallingDot(color: const Color(0xFF4B8673), size: 80))
                : SizedBox(
                    height: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAddOnTile("None", null, 1),
                          ...addOnsList.map((addOn) {
                            final name = addOn["name"];
                            final price = addOn["price"];
                            final int quantity = _addOnStock[name] ?? 0;
                            String priceText = price ?? "₱0";
                            if (quantity <= 0) {
                              priceText = "$priceText (Out of stock)";
                            }
                            return _buildAddOnTile(name, priceText, quantity);
                          }),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildConfirmButton("Confirm", () {
                  widget.onAddOnsSelected(_selectedAddOns);
                  _handleConfirmation();
                }),
                _buildCancelButton("Cancel", () {
                  Navigator.of(context).pop();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOnTile(String? name, String? price, int quantity) {
    bool isNone = name == "None";
    bool isDisabled = quantity <= 0 && !isNone;

    return ListTile(
      title: Text(name ?? "Unknown Add-on", style: isDisabled ? const TextStyle(color: Colors.grey) : null),
      subtitle: price != null ? Text(price) : null,
      trailing: Checkbox(
        activeColor: const Color(0xFF4B8673),
        value: isNone ? _selectedAddOns.isEmpty : _selectedAddOns.contains(name),
        onChanged: isDisabled ? null : (bool? value) {
          if (!_mounted) return;
          
          setState(() {
            if (value == true) {
              if (isNone) {
                _selectedAddOns.clear();
              } else {
                _selectedAddOns.add(name ?? "");
              }
            } else {
              if (!isNone) {
                _selectedAddOns.remove(name ?? "");
              }
            }
          });
        },
      ),
    );
  }

  Widget _buildConfirmButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4B8673),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildCancelButton(String text, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
      child: Text(text),
    );
  }
}