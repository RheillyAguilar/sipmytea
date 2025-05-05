import 'dart:math';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sipmytea/page/create_account.dart';
import 'package:sipmytea/page/daily_page.dart';
import 'package:sipmytea/page/finished_page.dart';
import 'package:sipmytea/page/inventory_page.dart';
import 'package:sipmytea/page/monthly_page.dart';
import 'package:sipmytea/page/sales_page.dart';
import 'package:sipmytea/page/stock_page.dart';

class NavigationWidget extends StatefulWidget {
  final bool isAdmin;
  final String username;

  const NavigationWidget({
    Key? key,
    required this.isAdmin,
    required this.username,
  }) : super(key: key);

  @override
  State<NavigationWidget> createState() => _NavigationWidgetState();
}

class _NavigationWidgetState extends State<NavigationWidget> {
  late final String profileImage;

  @override
  void initState() {
    super.initState();
    final random = Random();
    int index = random.nextInt(5) + 1;
    profileImage = 'assets/profile$index.jpg';
  }

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void selectedItem(BuildContext context, int index) {
    Navigator.of(context).pop();

    switch (index) {
      case 0:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => InventoryPage(username: widget.username)));
        break;
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => FinishedPage()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesPage(username: widget.username)));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => StockPage(isAdmin: widget.isAdmin,)));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => MonthlyPage()));
        break;
      case 5:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateAccount()));
        break;
      case 6:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DailyPage(username: widget.username, isAdmin: widget.isAdmin),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      backgroundColor: const Color(0xFFdfebe6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                buildHeader(image: profileImage, name: widget.username),
                const Divider(thickness: 1),
                buildItem(text: 'Sales', icon: Iconsax.money, onClicked: () => selectedItem(context, 2)),
                buildItem(text: 'Inventory', icon: Icons.inventory_2_outlined, onClicked: () => selectedItem(context, 0)),
                if (widget.isAdmin) buildItem(text: 'Daily Summary', icon: Iconsax.graph, onClicked: () => selectedItem(context, 6)),
                if (widget.isAdmin) buildItem(text: 'Monthly Sales', icon: Iconsax.calendar, onClicked: () => selectedItem(context, 4)),
                buildItem(text: 'Finished Goods', icon: Iconsax.document, onClicked: () => selectedItem(context, 1)),
                buildItem(text: 'Stock', icon: Iconsax.box4, onClicked: () => selectedItem(context, 3)),
                if (widget.isAdmin) buildItem(text: 'Create Account', icon: Iconsax.user_add, onClicked: () => selectedItem(context, 5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/');
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B8673),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader({required String image, required String name}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 60, 10, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Image.asset(image, height: 50, width: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              capitalizeFirstLetter(name),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildItem({
    required String text,
    required IconData icon,
    VoidCallback? onClicked,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      hoverColor: const Color(0xFFFFE3B0),
      onTap: onClicked,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
