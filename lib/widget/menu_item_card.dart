import 'package:flutter/material.dart';

class MenuItemCard extends StatelessWidget {
  final Map<String, String> item;
  final String selectedCategory;
  final String? selectedSize;
  final Function(String?) onSizeSelected;
  final VoidCallback onSelect;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.selectedCategory,
    required this.selectedSize,
    required this.onSizeSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item["name"] ?? "Unknown Item",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (selectedCategory == "Snack" || selectedCategory == "Silog")
              Text("Price: ${item["price"] ?? "N/A"}", style: const TextStyle(fontSize: 15))
            else
              Column(
                children: ["Regular", "Large"].map((size) {
                  if (item[size] != null) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("$size: ${item[size]}", style: const TextStyle(fontSize: 15)),
                        Radio<String>(
                          value: size,
                          groupValue: selectedSize,
                          onChanged: onSizeSelected,
                          activeColor: const Color(0xFF4B8673),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B8673),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Select", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
