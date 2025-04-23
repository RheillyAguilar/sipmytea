import './widget/cart_item.dart';

List<CartItem> cartItems = [];

// New model for sales
class SaleItem {
  final CartItem item;
  final DateTime dateTime;

  SaleItem({required this.item, required this.dateTime});
}

List<SaleItem> sales = [];
double monthlySales = 0.0;

