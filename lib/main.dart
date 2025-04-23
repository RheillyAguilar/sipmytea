import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sipmytea/page/account_page.dart';
import 'package:sipmytea/page/cart_page.dart';
import 'package:sipmytea/page/main_screen.dart';
import 'package:sipmytea/widget/navigation_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B8673),
          background: const Color(0xFFF9F9F9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      ),
      home: const LoginPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  final bool isAdmin;
  final String username;

  const MainPage({super.key, required this.isAdmin, required this.username});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  List<Widget> get page => [
        MainScreen(),
        CartPage(
          username: widget.username,
          onOrderConfirmed: () {
            setState(() {
              selectedIndex = 0;
            });
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    String currentDate = DateFormat('MMMM d, y').format(DateTime.now());

    return Scaffold(
      drawer: NavigationWidget(
        isAdmin: widget.isAdmin,
        username: widget.username,
      ),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.username[0].toUpperCase()}${widget.username.substring(1)}',
            ),
            Text(
              currentDate,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        onDestinationSelected: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Iconsax.receipt_item),
            selectedIcon: Icon(Iconsax.receipt_item5),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Iconsax.shopping_bag),
            selectedIcon: Icon(Iconsax.shopping_bag5),
            label: 'Cart',
          ),
        ],
      ),
      body: page[selectedIndex],
    );
  }
}
