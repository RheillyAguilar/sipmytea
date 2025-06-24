import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromoModel {
  final String id;
  final String name;
  final bool isActive;
  final List<String> discounts;
  final DateTime? startDate;
  final DateTime? endDate;

  PromoModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.discounts,
    this.startDate,
    this.endDate,
  });

  factory PromoModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PromoModel(
      id: doc.id, // This will be the promo name
      name: data['name'] ?? '',
      isActive: data['isActive'] ?? false,
      discounts: List<String>.from(data['discounts'] ?? []),
      startDate: data['startDate'] != null ? (data['startDate'] as Timestamp).toDate() : null,
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isActive': isActive,
      'discounts': discounts,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    };
  }

  // Check if promo is currently valid based on dates
  bool get isCurrentlyValid {
    final now = DateTime.now();
    
    // If start date is set and current time is before start date
    if (startDate != null && now.isBefore(startDate!)) {
      return false;
    }
    
    // If end date is set and current time is after end date
    if (endDate != null && now.isAfter(endDate!)) {
      return false;
    }
    
    return true;
  }

  // Check if promo has expired
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  // Get promo status text
  String get statusText {
    final now = DateTime.now();
    
    if (startDate != null && now.isBefore(startDate!)) {
      return 'Upcoming';
    } else if (endDate != null && now.isAfter(endDate!)) {
      return 'Expired';
    } else if (isActive && isCurrentlyValid) {
      return 'Active';
    } else {
      return 'Inactive';
    }
  }

  // Get status color
  Color get statusColor {
    switch (statusText) {
      case 'Active':
        return Colors.green;
      case 'Upcoming':
        return Colors.orange;
      case 'Expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class Promo extends StatefulWidget {
  final bool isAdmin;
  final List<String> appliedDiscounts; // Add this parameter

  const Promo({super.key, required this.isAdmin, this.appliedDiscounts = const []});

  @override
  State<Promo> createState() => _PromoState();
}

class _PromoState extends State<Promo> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );
    _fabAnimationController.forward();
    
    // Start automatic cleanup for expired promos
    _startAutomaticCleanup();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  // Automatic cleanup of expired promos
  void _startAutomaticCleanup() {
    // Check for expired promos every hour
    Future.delayed(const Duration(hours: 1), () {
      if (mounted) {
        _cleanupExpiredPromos();
        _startAutomaticCleanup(); // Schedule next cleanup
      }
    });
    
    // Also run cleanup immediately
    _cleanupExpiredPromos();
  }

  Future<void> _cleanupExpiredPromos() async {
    try {
      final snapshot = await _firestore.collection('promo').get();
      final now = DateTime.now();
      
      for (final doc in snapshot.docs) {
        final promo = PromoModel.fromFirestore(doc);
        
        // Delete if promo has expired
        if (promo.endDate != null && now.isAfter(promo.endDate!)) {
          await _firestore.collection('promo').doc(doc.id).delete();
          if (mounted) {
            print('Automatically deleted expired promo: ${promo.name}');
          }
        }
      }
    } catch (e) {
      print('Error during automatic cleanup: $e');
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  // Filter out applied discounts from available discounts
  List<String> _getAvailableDiscounts(List<String> promoDiscounts) {
    return promoDiscounts.where((discount) {
      return !widget.appliedDiscounts.any((applied) => 
        applied.toLowerCase().contains(discount.toLowerCase()) ||
        discount.toLowerCase().contains(applied.toLowerCase())
      );
    }).toList();
  }

  Future<void> _deletePromo(PromoModel promo) async {
    bool? confirmed = await _showDeleteWarning(promoName: promo.name);
    if (confirmed == true) {
      try {
        // Delete using the promo name as document ID
        await _firestore.collection('promo').doc(promo.name).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_capitalizeFirstLetter(promo.name)} deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting promo: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showDeleteWarning({required String promoName}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Promo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete "$promoName"? This action cannot be undone.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4b8673),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddPromoBottomModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPromoBottomModal(firestore: _firestore),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Promo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF2C3E50),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('promo').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final promos = snapshot.data!.docs
              .map((doc) => PromoModel.fromFirestore(doc))
              .toList();

          if (promos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_offer_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No promos yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isAdmin 
                        ? 'Tap the + button to add your first promo'
                        : 'Check back later for new promos',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: promos.length,
            itemBuilder: (context, index) {
              final promo = promos[index];
              final availableDiscounts = _getAvailableDiscounts(promo.discounts);
              
              // Modern card design
              Widget promoCard = Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: promo.isCurrentlyValid && promo.isActive
                        ? [Colors.white, const Color(0xFFF8FAFC)]
                        : [const Color(0xFFFAFAFA), const Color(0xFFF0F0F0)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 40,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                  border: Border.all(
                    color: promo.isCurrentlyValid && promo.isActive 
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Promo header with icon on left, name on right, and active badge below
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon on the left
                          Container(
                            padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200, width: 1),
                              ),
                            child: Icon(
                              Icons.local_offer,
                              size: 35,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Promo name and active badge on the right
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _capitalizeFirstLetter(promo.name),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F2937),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Status badge positioned under the promo name
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.shade300, width: 1),
                                  ),
                                  child: Text(
                                    promo.statusText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: Colors.amber.shade600
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Date information section
                      if (promo.startDate != null || promo.endDate != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Promo Duration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (promo.startDate != null) ...[
                                Row(
                                  children: [
                                    Icon(Icons.play_arrow, size: 16, color: Colors.blue.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Start: ${_formatDate(promo.startDate)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (promo.endDate != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.stop, size: 16, color: Colors.blue.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      'End: ${_formatDate(promo.endDate)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Available Promos Section - only show if promo is currently valid
                      if (promo.isCurrentlyValid && promo.isActive && availableDiscounts.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50, 
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                availableDiscounts.length == 1 
                                    ? 'Available Promo:'
                                    : 'Available Promos:',
                                style:  TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Colors.red.shade700
                                ),
                              ),
                              const SizedBox(height: 8),
                              // List each discount as a separate line
                              ...availableDiscounts.map((discount) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.local_offer_outlined, size: 18, color: Colors.red.shade700,),
                                    const SizedBox(width: 10),
                                    Text(
                                    _capitalizeFirstLetter(discount),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red.shade700
                                    ),
                                  ),
                                  ]
                                ),
                              )).toList(),
                            ],
                          ),
                        ),
                      ] else if (promo.isCurrentlyValid && promo.isActive && promo.discounts.isNotEmpty && availableDiscounts.isEmpty) ...[
                        // Show "All discounts from this promo are applied" message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'All discounts from this promo are applied',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (!promo.isCurrentlyValid || !promo.isActive) ...[
                        // Show why promo is not available
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                promo.isExpired ? Icons.timer_off : Icons.info_outline,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  promo.isExpired 
                                      ? 'This promo has expired'
                                      : !promo.isActive 
                                          ? 'This promo is currently inactive'
                                          : 'This promo is not yet available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (promo.discounts.isEmpty) ...[
                        // Show "No discounts configured" if promo has no discounts
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'No discounts configured',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );

              // Wrap with Slidable only for admin users
              if (widget.isAdmin) {
                return Slidable(
                  key: ValueKey(promo.id),
                  endActionPane: ActionPane(
                    motion: const BehindMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _deletePromo(promo),
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.red,
                        icon: Icons.delete_forever,
                        label: 'Delete',
                        borderRadius: BorderRadius.circular(20),
                        spacing: 4,
                      ),
                    ],
                  ),
                  child: promoCard,
                );
              }
              
              return promoCard;
            },
          );
        },
      ),
      // Show FAB only for admin users
      floatingActionButton: widget.isAdmin
          ? ScaleTransition(
              scale: _fabAnimation,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4B8673), Color(0xFF3A6B5C)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4B8673).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _showAddPromoBottomModal,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            )
          : null,
    );
  }
}

class AddPromoBottomModal extends StatefulWidget {
  final FirebaseFirestore firestore;

  const AddPromoBottomModal({super.key, required this.firestore});

  @override
  State<AddPromoBottomModal> createState() => _AddPromoBottomModalState();
}

class _AddPromoBottomModalState extends State<AddPromoBottomModal> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  List<String> discounts = [];
  bool isActive = true;
  bool isLoading = false;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void dispose() {
    nameController.dispose();
    discountController.dispose();
    super.dispose();
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4B8673),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          // If end date is before start date, clear it
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null;
          }
        } else {
          // Validate that end date is after start date
          if (startDate != null && picked.isBefore(startDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('End date must be after start date'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          endDate = picked;
        }
      });
    }
  }

  Future<void> _addPromo() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a promo name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate dates
    if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Capitalize the promo name before checking/saving
      String capitalizedName = _capitalizeFirstLetter(nameController.text.trim());
      
      // Check if promo name already exists
      final docSnapshot = await widget.firestore
          .collection('promo')
          .doc(capitalizedName)
          .get();
      
      if (docSnapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Promo "$capitalizedName" already exists'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        setState(() => isLoading = false);
        return;
      }

      // Capitalize all discounts before saving
      List<String> capitalizedDiscounts = discounts
          .map((discount) => _capitalizeFirstLetter(discount))
          .toList();

      // Create the promo model
      final promo = PromoModel(
        id: capitalizedName,
        name: capitalizedName,
        isActive: isActive,
        discounts: capitalizedDiscounts,
        startDate: startDate,
        endDate: endDate,
      );

      // Use the capitalized promo name as the document ID
      await widget.firestore.collection('promo').doc(capitalizedName).set(promo.toFirestore());
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Promo added successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding promo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _addDiscount() {
    if (discountController.text.isNotEmpty) {
      setState(() {
        discounts.add(discountController.text.trim());
        discountController.clear();
      });
    }
  }

  void _removeDiscount(int index) {
    setState(() {
      discounts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Add New Promo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Promo Name
                        const Text(
                          'Promo Name',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter promo name',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF4B8673)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Active Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Active Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            Switch(
                              value: isActive,
                              onChanged: (value) => setState(() => isActive = value),
                              activeColor: const Color(0xFF4B8673),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Date Selection
                        const Text(
                          'Promo Duration (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectDate(context, true),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(startDate),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: startDate != null 
                                              ? const Color(0xFF374151) 
                                              : Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectDate(context, false),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(endDate),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: endDate != null 
                                              ? const Color(0xFF374151) 
                                              : Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        if (startDate != null || endDate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (startDate != null)
                                TextButton.icon(
                                  onPressed: () => setState(() => startDate = null),
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear Start'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey.shade600,
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              if (endDate != null)
                                TextButton.icon(
                                  onPressed: () => setState(() => endDate = null),
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear End'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey.shade600,
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Discounts Section
                        const Text(
                          'Discounts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Add discount input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: discountController,
                                decoration: InputDecoration(
                                  hintText: 'Enter discount name',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF4B8673)),
                                  ),
                                ),
                                onSubmitted: (_) => _addDiscount(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _addDiscount,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4B8673),
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Discount list
                        if (discounts.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Added Discounts:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...discounts.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  String discount = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.blue.shade200),
                                            ),
                                            child: Text(
                                              _capitalizeFirstLetter(discount),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _removeDiscount(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _addPromo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B8673),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Add Promo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}