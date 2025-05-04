import 'package:flutter/material.dart';
import 'package:sipmytea/cart_data.dart';
import 'package:sipmytea/widget/addon_selection.dart';
import 'package:sipmytea/widget/cart_item.dart';
import '../menu_data.dart';
import '../widget/menu_item_card.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedCategory = 0;
  final List<String> categories = [
    "Classic Milktea",
    "Smoothies",
    "Creampuff Overload",
    "Fresh Tea",
    "Snack",
    "Silog",
  ];

  final Map<int, String?> _selectedSizes = {};
  final Map<int, Set<String>> _selectedAddOns = {};
  final ScrollController _scrollController = ScrollController();

  void _showAddOnsDialog(BuildContext context, Map<String, String> selectedItem, int index, String selectedSize, selectedCategoryName
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddonSelection(
          selectedItem: {
            ...selectedItem,
            'size': selectedSize,
            'category': selectedCategoryName, 
          },
          selectedAddOns: _selectedAddOns[index] ?? {},
          onAddOnsSelected: (selectedAddOns) {
            setState(() {
              _selectedAddOns[index] = selectedAddOns;
              _selectedSizes[index] = selectedSize;
            });
          },
        );
      },
    );
  }

  void _showSnackSilogConfirmationDialog(BuildContext context, Map<String, String> selectedItem, String category) {
    String productName = selectedItem["name"] ?? "Unknown";
    String priceText = selectedItem["price"] ?? "₱0";
    int price = int.parse(priceText.replaceAll("₱", ""));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Order Confirmation"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Product: $productName"),
              Text(
                "Total Price: ₱$price",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                cartItems.add(
                  CartItem(
                    productName: productName,
                    size: "N/A",
                    addOns: [],
                    totalPrice: price,
                    category: category,
                  ),
                );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B8673),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                )
              ),
              child: const Text("Confirm", style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

  void _onCategoryChanged(int index) {
    setState(() {
      _selectedCategory = index;
      _selectedSizes.clear();
    });

    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String selectedCategoryName = categories[_selectedCategory];
    List<Map<String, String>> filteredItems = menuItems[selectedCategoryName] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Categories", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(categories[index]),
                    selected: _selectedCategory == index,
                    onSelected: (_) => _onCategoryChanged(index),
                    selectedColor: const Color(0xFF4B8673),
                    labelStyle: TextStyle(
                      color: _selectedCategory == index ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .68,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                return MenuItemCard(
                  item: filteredItems[index],
                  selectedCategory: selectedCategoryName,
                  selectedSize: _selectedSizes[index],
                  onSizeSelected: (value) {
                    setState(() {
                      _selectedSizes[index] = value;
                    });
                  },
                  onSelect: () {
                    if ((selectedCategoryName != "Snack" && selectedCategoryName != "Silog") && _selectedSizes[index] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a size before proceeding.")),
                      );
                    } else {
                      if (selectedCategoryName == "Snack" || selectedCategoryName == "Silog") {
                        _showSnackSilogConfirmationDialog(context, filteredItems[index], selectedCategoryName);
                      } else {
                        _showAddOnsDialog(context, filteredItems[index], index, _selectedSizes[index]!, selectedCategoryName);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}