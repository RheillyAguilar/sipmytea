// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedAddOns = Set.from(widget.selectedAddOns);
  }

  void _showCheckDialog(BuildContext context) {
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
                            const SnackBar(
                              content: Text("Please input a name"),
                            ),
                          );
                        } else {
                          Navigator.of(context).pop();
                          String rawName = nameController.text.trim();
                          String capitalized =
                              rawName[0].toUpperCase() + rawName.substring(1);
                          _showConfirmationDialog(context, capitalized);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B8673),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Confirm',
                          style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
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

  void _showConfirmationDialog(BuildContext context, String name) {
    String productName = widget.selectedItem["name"] ?? "Unknown";
    String? size = widget.selectedItem["size"]?.isEmpty ?? true
        ? "Large"
        : widget.selectedItem["size"];
    String basePrice =
        widget.selectedItem[size == "Large" ? "Large" : "Regular"] ?? "₱0";

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
                Text("Product: $productName",
                    style: const TextStyle(fontSize: 18)),
                Text("Size: $size", style: const TextStyle(fontSize: 18)),
                if (_selectedAddOns.isNotEmpty) ...[
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
                  "Thank you $name, please buy again!",
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
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

                      setState(() {
                        _selectedAddOns.clear();
                      });

                      Navigator.of(context).pop();
                      Navigator.of(this.context).pop();

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text("Order added!"),
                        ),
                      );
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
            const Text(
              "Select Add-ons",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAddOnTile("None", null),
                    ...menuItems["Add-ons"]!.map(
                      (addOn) => _buildAddOnTile(
                        addOn["name"],
                        addOn["price"],
                      ),
                    ),
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

  Widget _buildAddOnTile(String? name, String? price) {
    bool isNone = name == "None";
    return ListTile(
      title: Text(name ?? "Unknown Add-on"),
      subtitle: price != null ? Text("Price: $price") : null,
      trailing: Checkbox(
        activeColor: const Color(0xFF4B8673),
        value:
            isNone ? _selectedAddOns.isEmpty : _selectedAddOns.contains(name),
        onChanged: (bool? value) {
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
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
