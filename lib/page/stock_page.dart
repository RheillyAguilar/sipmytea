import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iconsax/iconsax.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  final List<Map<String, String>> _stocks = [];

  void _showAddStockSheet({int? editIndex}) {
    bool isEditing = editIndex != null;
    if (isEditing) {
      _nameController.text = _stocks[editIndex]['name'] ?? '';
      _numberController.text = _stocks[editIndex]['number'] ?? '';
    } else {
      _nameController.clear();
      _numberController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Edit Stock' : 'Add New Stock',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration('Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Quantity'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                String name = _nameController.text.trim();
                String number = _numberController.text.trim();
                if (name.isNotEmpty && number.isNotEmpty) {
                  setState(() {
                    if (isEditing) {
                      _stocks[editIndex] = {'name': name, 'number': number};
                    } else {
                      _stocks.add({'name': name, 'number': number});
                    }
                  });
                  Navigator.pop(context);
                }
                _nameController.clear();
                _numberController.clear();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF4B8673),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isEditing ? 'Save' : 'Add', style: TextStyle(
                color: Colors.white
              ),),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _confirmDelete(int index) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Stock?'),
          content: const Text('Are you sure to delete this stock?'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide.none
                )
              ),
              child: const Text('Delete',style: TextStyle(
                color: Colors.white
              ),),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700]
              ),
              child: const Text('Cancel'),
            ),
            
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      setState(() {
        _stocks.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _stocks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Iconsax.box, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No stocks yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stocks.length,
              itemBuilder: (context, index) {
                final stock = _stocks[index];
                return Slidable(
                  key: ValueKey(stock['name']! + index.toString()),
                  startActionPane: _buildActionPane(index),
                  endActionPane: _buildActionPane(index),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 3,
                    child: ListTile(
                      leading: const Icon(Iconsax.box, color: Color(0xFF4B8673)),
                      title: Text(
                        stock['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Quantity: ${stock['number']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStockSheet(),
        backgroundColor: const Color(0xFF4B8673),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  ActionPane _buildActionPane(int index) {
    return ActionPane(
      motion: const DrawerMotion(),
      children: [
        SlidableAction(
          onPressed: (_) => _showAddStockSheet(editIndex: index),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          icon: Icons.edit,
          label: 'Edit',
        ),
        SlidableAction(
          onPressed: (_) => _confirmDelete(index),
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          icon: Icons.delete,
          label: 'Delete',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }
}
