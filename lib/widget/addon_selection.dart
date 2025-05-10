import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
  Map<String, int> _addOnStock = {}; // Stock map
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedAddOns = Set.from(widget.selectedAddOns);
    _loadStock(); // Fetch stock on init
  }

  Future<void> _loadStock() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get stock collection data
      QuerySnapshot stockSnapshot = await firestore.collection('stock').get();
      Map<String, int> stockMap = {};
      
      // Process stock data
      for (var doc in stockSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        stockMap[data['name']] = data['quantity'] ?? 0;
      }

      // Check finished_goods collection specifically for Creampuff, Pearl, and Salted cheese
      QuerySnapshot finishedGoodsSnapshot = await firestore.collection('finished_goods').get();
      for (var doc in finishedGoodsSnapshot.docs) {
        String docName = doc.id;
        if (docName == 'Creampuff' || docName == 'Pearl' || docName == 'Salted cheese') {
          // Get the item quantity from the document
          int quantity = 0;
          
          // Check if the document has a quantity field directly
          var data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('quantity')) {
            quantity = data['quantity'] as int;
          }
          // Alternatively check for nested fields like canDo or name/quantity pairs
          else if (data.containsKey('name') && data['name'] == docName && data.containsKey('quantity')) {
            quantity = data['quantity'] as int;
          }
          
          stockMap[docName] = quantity;
        }
      }

      setState(() {
        _addOnStock = stockMap;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stock: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCheckDialog(BuildContext context) {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Enter Your Name",
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
                      borderSide: BorderSide.none,
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
                            const SnackBar(content: Text("Please input a name")),
                          );
                        } else {
                          Navigator.of(context).pop();
                          String rawName = nameController.text.trim();
                          String capitalized = rawName[0].toUpperCase() + rawName.substring(1);
                          _showConfirmationDialog(context, capitalized);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B8673),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
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

  void _showConfirmationDialog(BuildContext context, String name) {
    String productName = widget.selectedItem["name"] ?? "Unknown";
    String? size = widget.selectedItem["size"]?.isEmpty ?? true ? "Large" : widget.selectedItem["size"];
    String basePrice = widget.selectedItem[size == "Large" ? "Large" : "Regular"] ?? "₱0";
    int totalPrice = int.parse(basePrice.replaceAll("₱", ""));
    
    for (String addOn in _selectedAddOns) {
      var addOnItem = menuItems["Add-ons"]!.firstWhere(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Order Confirmation", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text("Product: $productName", style: const TextStyle(fontSize: 18)),
                Text("Size: $size", style: const TextStyle(fontSize: 18)),
                if (_selectedAddOns.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text("Add-ons:", style: TextStyle(fontWeight: FontWeight.bold)),
                  for (String addOn in _selectedAddOns) Text("- $addOn", style: const TextStyle(fontSize: 16)),
                ],
                const SizedBox(height: 12),
                Text("Thank you $name, please buy again!", style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      cartItems.add(
                        CartItem(
                          productName: productName,
                          size: size!,
                          addOns: _selectedAddOns.toList(),
                          totalPrice: totalPrice,
                          category: widget.selectedItem['category'] ?? '',
                        ),
                      );
                      
                      // Update stock in Firestore after confirming order
                      _updateStockInFirestore();
                      
                      setState(() {
                        _selectedAddOns.clear();
                      });
                      Navigator.of(context).pop();
                      Navigator.of(this.context).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Order added!")));
                    },
                    child: const Text("Confirm"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to update stock in Firestore after order is confirmed
  Future<void> _updateStockInFirestore() async {
    // Only update if there are add-ons selected
    if (_selectedAddOns.isEmpty) return;
    
    // For each add-on, update its stock in appropriate collection
    for (String addOn in _selectedAddOns) {
      // Check if this is a special item (Creampuff, Pearl, Salted Cheese)
      if (addOn == 'Creampuff' || addOn == 'Pearl' || addOn == 'Salted cheese') {
        // Update in finished_goods collection
        try {
          DocumentSnapshot doc = await firestore.collection('finished_goods').doc(addOn).get();
          if (doc.exists) {
            var data = doc.data() as Map<String, dynamic>;
            int currentQuantity = 0;
            
            // Get current quantity
            if (data.containsKey('quantity')) {
              currentQuantity = data['quantity'] as int;
            }
            
            // Update quantity (reduce by 1)
            if (currentQuantity > 0) {
              await firestore.collection('finished_goods').doc(addOn).update({
                'quantity': currentQuantity - 1
              });
            }
          }
        } catch (e) {
          print('Error updating stock for $addOn: $e');
        }
      } else {
        // Update in stock collection for regular add-ons
        try {
          QuerySnapshot querySnapshot = await firestore
              .collection('stock')
              .where('name', isEqualTo: addOn)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            DocumentSnapshot doc = querySnapshot.docs.first;
            int currentQuantity = (doc.data() as Map<String, dynamic>)['quantity'] ?? 0;
            
            if (currentQuantity > 0) {
              await firestore.collection('stock').doc(doc.id).update({
                'quantity': currentQuantity - 1
              });
            }
          }
        } catch (e) {
          print('Error updating stock for $addOn: $e');
        }
      }
    }
    
    // Refresh stock data after update
    _loadStock();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Add-ons", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 10),
            _isLoading
                ? Center(child:  LoadingAnimationWidget.fallingDot(color: Color(0xFF4B8673), size: 80))
                : SizedBox(
                    height: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAddOnTile("None", null, 1), // Always enabled
                          ...menuItems["Add-ons"]!.map((addOn) {
                            final name = addOn["name"];
                            final price = addOn["price"];
                                                        
                            // Get stock quantity (default to 0 if not found)
                            final int quantity = _addOnStock[name] ?? 0;
                            
                            // Add a note for out of stock items
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
                  _showCheckDialog(context);
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
    bool isDisabled = quantity <= 0 && !isNone; // "None" option is always enabled

    return ListTile(
      title: Text(
        name ?? "Unknown Add-on", 
        style: isDisabled ? const TextStyle(color: Colors.grey) : null
      ),
      subtitle: price != null ? Text(price) : null,
      trailing: Checkbox(
        activeColor: const Color(0xFF4B8673),
        value: isNone ? _selectedAddOns.isEmpty : _selectedAddOns.contains(name),
        onChanged: isDisabled ? null : (bool? value) {
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