class CartItem {
  final String productName;
  final String size;
  final List<String> addOns;
  final int totalPrice;

  CartItem({
    required this.productName,
    required this.size,
    required this.addOns,
    required this.totalPrice,
  });
}
