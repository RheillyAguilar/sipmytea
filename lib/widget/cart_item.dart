import 'package:sipmytea/cart_data.dart';

class CartItem {
  final String productName;
  final String size;
  final String? sugarLevel;
  final List<String> addOns;
  final int totalPrice;
  final String category;
  final int? originalPrice; // ✅ New field for original price before discount
  final int? discountAmount; // ✅ New field for discount amount
  final String? promoName; // ✅ New field for promo name

  CartItem({
    required this.productName,
    required this.size,
    required this.sugarLevel,
    required this.addOns,
    required this.totalPrice,
    required this.category,
    this.originalPrice, // ✅ Optional parameter
    this.discountAmount, // ✅ Optional parameter
    this.promoName, // ✅ Optional parameter
  });

  // ✅ Helper method to check if item has a discount
  bool get hasDiscount => discountAmount != null && discountAmount! > 0;

  // ✅ Helper method to get savings text
  String get savingsText {
    if (!hasDiscount) return '';
    return 'Saved ₱$discountAmount with $promoName';
  }
}

double get totalCartPrice {
  return cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
}

// ✅ Helper method to get total original price (before discounts)
double get totalOriginalPrice {
  return cartItems.fold(0.0, (sum, item) => sum + (item.originalPrice ?? item.totalPrice));
}

// ✅ Helper method to get total savings
double get totalSavings {
  return cartItems.fold(0.0, (sum, item) => sum + (item.discountAmount ?? 0));
}