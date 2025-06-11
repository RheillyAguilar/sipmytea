import 'package:sipmytea/page/cart_page.dart';

import './widget/cart_item.dart';

List<CartItem> cartItems = [];

// New model for sales
class SaleItem {
  final CartItem item;
  final DateTime dateTime;
  final PaymentMethod paymentMethod;

  SaleItem({required this.item, required this.dateTime, required this.paymentMethod});
}

List<SaleItem> sales = [];
double monthlySales = 0.0;

