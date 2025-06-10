import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Static cache for ingredients availability (shared across all instances)
  static final Map<String, bool> _ingredientCache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 2);

  // Check if cache is still valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  // Batch check all ingredients at once with caching
  Future<Map<String, dynamic>> _checkAvailabilityFast() async {
    String itemName = item["name"] ?? "Unknown Item";
    
    // Get all required ingredients
    Set<String> allRequiredIngredients = {};
    
    // Add Base if required
    if (_requiresBase(itemName)) {
      allRequiredIngredients.add('Base');
    }
    
    // Add finished goods ingredients
    allRequiredIngredients.addAll(_getFinishedGoodsIngredients(selectedCategory));
    
    // Add stock ingredients
    allRequiredIngredients.addAll(_getStockIngredients(itemName, selectedCategory));
    
    if (allRequiredIngredients.isEmpty) {
      return {'available': true, 'missingIngredients': <String>[]};
    }
    
    // Use cache if valid and all ingredients are cached
    if (_isCacheValid() && 
        allRequiredIngredients.every((ingredient) => _ingredientCache.containsKey(ingredient))) {
      List<String> missingIngredients = allRequiredIngredients
          .where((ingredient) => !(_ingredientCache[ingredient] ?? false))
          .toList();
      
      return {
        'available': missingIngredients.isEmpty,
        'missingIngredients': missingIngredients,
      };
    }
    
    // Batch check ingredients that are not in cache or cache is expired
    Set<String> ingredientsToCheck = allRequiredIngredients.where((ingredient) => 
        !_isCacheValid() || !_ingredientCache.containsKey(ingredient)).toSet();
    
    try {
      // Separate ingredients by collection
      Set<String> finishedGoodsToCheck = {};
      Set<String> stockToCheck = {};
      
      for (String ingredient in ingredientsToCheck) {
        if (_getFinishedGoodsIngredients(selectedCategory).contains(ingredient) || ingredient == 'Base') {
          finishedGoodsToCheck.add(ingredient);
        } else {
          stockToCheck.add(ingredient);
        }
      }
      
      // Batch check finished goods
      List<Future<DocumentSnapshot>> finishedGoodsFutures = finishedGoodsToCheck
          .map((ingredient) => FirebaseFirestore.instance
              .collection('finished_goods')
              .doc(ingredient)
              .get())
          .toList();
      
      // Batch check stock items
      List<Future<DocumentSnapshot>> stockFutures = stockToCheck
          .map((ingredient) => FirebaseFirestore.instance
              .collection('stock')
              .doc(ingredient)
              .get())
          .toList();
      
      // Wait for all queries to complete
      List<DocumentSnapshot> finishedGoodsResults = [];
      List<DocumentSnapshot> stockResults = [];
      
      if (finishedGoodsFutures.isNotEmpty) {
        finishedGoodsResults = await Future.wait(finishedGoodsFutures);
      }
      if (stockFutures.isNotEmpty) {
        stockResults = await Future.wait(stockFutures);
      }
      
      // Process finished goods results
      int finishedGoodsIndex = 0;
      for (String ingredient in finishedGoodsToCheck) {
        DocumentSnapshot doc = finishedGoodsResults[finishedGoodsIndex++];
        _ingredientCache[ingredient] = doc.exists;
      }
      
      // Process stock results
      int stockIndex = 0;
      for (String ingredient in stockToCheck) {
        DocumentSnapshot doc = stockResults[stockIndex++];
        bool available = false;
        
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          int quantity = data['quantity'] ?? 0;
          int limit = data['limit'] ?? 0;
          available = quantity > limit;
        }
        
        _ingredientCache[ingredient] = available;
      }
      
      // Update cache timestamp
      _lastCacheUpdate = DateTime.now();
      
      // Check final availability
      List<String> missingIngredients = allRequiredIngredients
          .where((ingredient) => !(_ingredientCache[ingredient] ?? false))
          .toList();
      
      return {
        'available': missingIngredients.isEmpty,
        'missingIngredients': missingIngredients,
      };
      
    } catch (e) {
      // On error, mark all ingredients as unavailable but don't cache the error
      return {
        'available': false,
        'missingIngredients': allRequiredIngredients.toList(),
      };
    }
  }

  // Clear cache method (call this when inventory is updated)
  static void clearCache() {
    _ingredientCache.clear();
    _lastCacheUpdate = null;
  }

  // Define which items require Base to be available (original logic)
  bool _requiresBase(String itemName) {
    String lowerName = itemName.toLowerCase().trim();
    
    if (selectedCategory == "Classic Milktea") {
      return true;
    }
    
    if (selectedCategory == "Creampuff Overload") {
      bool hasMatcha = lowerName.contains('matcha');
      bool hasCookies = lowerName.contains('cookies and cream');
      bool hasDarkChoco = lowerName.contains('dark chocolate');
      bool hasChocomalt = lowerName.contains('chocomalt');
      
      if (hasMatcha || hasCookies || hasDarkChoco || hasChocomalt) {
        return true;
      } else {
        return false;
      }
    }
    
    return false;
  }

  // Get additional required ingredients for each menu item
  List<String> _getAdditionalIngredients(String itemName, String category) {
    String lowerName = itemName.toLowerCase().trim();
    List<String> ingredients = [];

    if (category == "Classic Milktea") {
      // Add specific flavor ingredients (checked in stock collection)
      if (lowerName.contains('wintermelon')) ingredients.add('wintermelon');
      if (lowerName.contains('okinawa')) ingredients.add('okinawa');
      if (lowerName.contains('blueberry')) ingredients.add('blueberry');
      if (lowerName.contains('strawberry')) ingredients.add('strawberry');
      if (lowerName.contains('lychee')) ingredients.add('lychee');
      if (lowerName.contains('yogurt')) ingredients.add('yogurt');
      if (lowerName.contains('taro')) ingredients.add('taro');
      if (lowerName.contains('brown sugar')) ingredients.add('brown sugar');
      if (lowerName.contains('honeydew')) ingredients.add('honeydew');
      if (lowerName.contains('dark chocolate')) ingredients.add('dark chocolate');
      if (lowerName.contains('coffee')) ingredients.add('coffee');
      if (lowerName.contains('chocolate')) ingredients.add('chocolate');
    }
    
    else if (category == "Smoothies") {
      // All smoothie ingredients checked in stock collection
      ingredients.add('fresh milk');
      
      if (lowerName.contains('chocolate')) ingredients.add('chocolate');
      if (lowerName.contains('blueberry')) ingredients.add('blueberry');
      if (lowerName.contains('strawberry')) ingredients.add('strawberry');
      if (lowerName.contains('mixberries')) ingredients.addAll(['blueberry', 'strawberry']);
      if (lowerName.contains('coffee')) ingredients.add('coffee');
      if (lowerName.contains('dark chocolate')) ingredients.add('dark chocolate');
      if (lowerName.contains('mocha')) ingredients.add('mocha');
    }
    
    else if (category == "Creampuff Overload") {
      // Main ingredient checked in finished_goods
      ingredients.add('Creampuff');
      
      // Flavor ingredients checked in stock collection
      if (lowerName.contains('honeydew')) {
        ingredients.addAll(['fresh milk', 'honeydew']);
      }
      if (lowerName.contains('taro')) {
        ingredients.addAll(['fresh milk', 'taro']);
      }
      if (lowerName.contains('matcha')) {
        ingredients.addAll(['fresh milk', 'matcha']);
      }
      if (lowerName.contains('dark chocolate')) {
        ingredients.addAll(['fresh milk', 'dark chocolate']);
      }
      if (lowerName.contains('cookies and cream')) {
        ingredients.addAll(['fresh milk', 'oreo crumbs']);
      }
      if (lowerName.contains('chocomalt')) {
        ingredients.addAll(['fresh milk', 'chocomalt']);
      }
    }
    
    else if (category == "Fresh Tea") {
      // Main ingredient checked in finished_goods
      ingredients.add('Fresh tea');
      
      // Flavor ingredients checked in stock collection
      if (lowerName.contains('lychee')) ingredients.add('lychee');
      if (lowerName.contains('wintermelon')) ingredients.add('wintermelon');
      if (lowerName.contains('blueberry')) ingredients.add('blueberry');
      if (lowerName.contains('strawberry')) ingredients.add('strawberry');
      if (lowerName.contains('kiwi yakult')) ingredients.addAll(['kiwi yakult', 'yakult']);
    }
    
    else if (category == "Snack") {
      // Snack ingredients checked in stock collection
      if (lowerName.contains('regular beef') || lowerName.contains('regular burger')) {
        ingredients.addAll(['patties', 'buns', 'repolyo']);
      }
      if (lowerName.contains('cheese beef burger') || lowerName.contains('cheese burger')) {
        ingredients.addAll(['patties', 'buns', 'repolyo', 'slice cheese']);
      }
      if (lowerName.contains('egg sandwich')) {
        ingredients.addAll(['egg', 'buns', 'repolyo']);
      }
      if (lowerName.contains('cheesestick')) {
        ingredients.add('cheese stick');
      }
      if (lowerName.contains('fries')) {
        ingredients.add('fries');
      }
      if (lowerName.contains('combo')) {
        ingredients.addAll(['fries', 'buns', 'patties', 'slice cheese', 'cheese stick', 'repolyo']);
      }
    }

    return ingredients;
  }

  // Get ingredients that should be checked in finished_goods collection
  List<String> _getFinishedGoodsIngredients(String category) {
    List<String> finishedGoodsIngredients = [];
    
    if (category == "Creampuff Overload") {
      finishedGoodsIngredients.add('Creampuff');
    }
    
    if (category == "Fresh Tea") {
      finishedGoodsIngredients.add('Fresh tea');
    }
    
    return finishedGoodsIngredients;
  }

  // Get ingredients that should be checked in stock collection
  List<String> _getStockIngredients(String itemName, String category) {
    List<String> allIngredients = _getAdditionalIngredients(itemName, category);
    List<String> finishedGoodsIngredients = _getFinishedGoodsIngredients(category);
    
    // Remove finished goods ingredients from stock ingredients
    return allIngredients.where((ingredient) => 
        !finishedGoodsIngredients.contains(ingredient)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAvailabilityFast(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        bool isAvailable = snapshot.data?['available'] ?? false;
        List<String> missingIngredients = snapshot.data?['missingIngredients'] ?? [];
        
        return _buildCard(context, isAvailable, missingIngredients);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4B8673),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, bool isAvailable, List<String> missingIngredients) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isAvailable ? Colors.white : Colors.grey.shade200,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item["name"] ?? "Unknown Item",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isAvailable ? Colors.black : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              if (!isAvailable) ...[
                Text(
                  "Out of Stock",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (missingIngredients.isNotEmpty)
                  Text(
                    "Missing: ${missingIngredients.join(', ')}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 8),
              if (selectedCategory == "Snack" || selectedCategory == "Silog")
                Text(
                  "Price: ${item["price"] ?? "N/A"}", 
                  style: TextStyle(
                    fontSize: 15,
                    color: isAvailable ? Colors.black : Colors.grey.shade600,
                  ),
                )
              else
                Column(
                  children: ["Regular", "Large"].map((size) {
                    if (item[size] != null) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$size: ${item[size]}", 
                            style: TextStyle(
                              fontSize: 15,
                              color: isAvailable ? Colors.black : Colors.grey.shade600,
                            ),
                          ),
                          Radio<String>(
                            value: size,
                            groupValue: selectedSize,
                            onChanged: isAvailable ? onSizeSelected : null,
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
                  onPressed: isAvailable ? onSelect : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAvailable 
                        ? const Color(0xFF4B8673) 
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isAvailable ? "Select" : "Unavailable",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}