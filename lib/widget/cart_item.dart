class CartItem {
  final String productName;
  final String size;
  final String? sugarLevel;
  final List<String> addOns;
  final int totalPrice;
  final String category; // ✅ New field

  CartItem({
    required this.productName,
    required this.size,
    required this.sugarLevel,
    required this.addOns,
    required this.totalPrice,
    required this.category, // ✅ Include in constructor
  });
}
