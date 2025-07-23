import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

// Custom input formatter for currency codes (alphabetic uppercase only)
class UppercaseAlphabeticInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Filter out non-alphabetic characters and convert to uppercase
    final filteredText = newValue.text.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    
    return TextEditingValue(
      text: filteredText,
      selection: TextSelection.collapsed(offset: filteredText.length),
    );
  }
}

// Floating particle class
class _FloatingParticle {
  final double x = math.Random().nextDouble();
  final double y = math.Random().nextDouble();
  final double size = math.Random().nextDouble() * 4 + 2;
  final double speed = math.Random().nextDouble() * 0.5 + 0.1;
  final double angle = math.Random().nextDouble() * 2 * math.pi;
}

// Custom painter for floating particles
class _FloatingParticlesPainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final Animation<double> animation;

  _FloatingParticlesPainter({
    required this.particles,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      final x = (particle.x + animation.value * particle.speed) * size.width;
      final y = (particle.y + math.sin(animation.value * 2 * math.pi + particle.angle) * 20) * size.height;
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// This file now only contains the EmailSenderPage widget
// The main app entry point has been moved to app.dart

// Initialize Firebase and run the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class EmailSenderPage extends StatefulWidget {
  const EmailSenderPage({super.key});

  @override
  State<EmailSenderPage> createState() => _EmailSenderPageState();
}

class _EmailSenderPageState extends State<EmailSenderPage> with TickerProviderStateMixin {
  // Add keyboard listener
  final FocusNode _focusNode = FocusNode();
  bool _showAdminSection = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _floatingController;
  late AnimationController _glowController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _glowAnimation;

  // Floating particles
  final List<_FloatingParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    // Setup animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _floatingController.repeat();
    _glowController.repeat(reverse: true);
    
    // Initialize floating particles
    _initializeParticles();
  }

  void _initializeParticles() {
    for (int i = 0; i < 15; i++) {
      _particles.add(_FloatingParticle());
    }
  }

  @override
  void dispose() {
    // Clean up all text editing controllers
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    _dropdownValues.clear();
    _focusNode.dispose();
    
    // Dispose animation controllers
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _floatingController.dispose();
    _glowController.dispose();
    
    super.dispose();
  }

  // Handle keyboard shortcuts
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final isControlPressed = event.isControlPressed;
      final isShiftPressed = event.isShiftPressed;
      final isKeyA = event.logicalKey == LogicalKeyboardKey.keyA;

      if (isControlPressed && isShiftPressed && isKeyA) {
        setState(() {
          _showAdminSection = !_showAdminSection;
        });
      }
    }
  }

  // Build enhanced admin section
  Widget _buildAdminSection() {
    if (!_showAdminSection) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade900,
                Colors.grey.shade800,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade700),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.amber.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.shade400.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Admin Section (Firebase CLI Commands)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildCommandSection(
                title: 'View Current Email Password',
                command: 'firebase functions:secrets:access EMAIL_APP_PASSWORD',
                description: 'Shows the current value of the email app password.',
              ),
              const SizedBox(height: 16),
              _buildCommandSection(
                title: 'Update Email Password',
                command: 'firebase functions:secrets:set EMAIL_APP_PASSWORD',
                description: 'Sets a new value for the email app password. You will be prompted to enter the new value.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade100.withOpacity(0.1),
                      Colors.amber.shade200.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.amber.shade300,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Press Ctrl+Shift+A again to hide this section',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade300,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build enhanced command sections
  Widget _buildCommandSection({
    required String title,
    required String command,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade900,
                  Colors.grey.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade600),
            ),
            child: Text(
              command,
              style: TextStyle(
                color: Colors.amber.shade300,
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // File processing variables
  String? _selectedFileName;
  String? _fileContent;
  bool _isFileProcessed = false;
  String _processingStatus = '';
  List<List<String>>? _csvData;
  List<String>? _csvHeaders;
  
  // Filter variables
  String _filterText = '';
  List<List<String>>? _filteredData;
  int? _transactionIdIndex;
  int? _publisherTransactionIdIndex;
  
  // Editing variables
  Map<String, int> _editableColumns = {};
  Map<String, bool> _isEditing = {};
  Map<String, TextEditingController> _editControllers = {};
  Map<String, String> _dropdownValues = {};
  
  // Column reordering
  List<int>? _columnOrder;
  List<String>? _reorderedHeaders;
  
  // Track edited rows
  Set<int> _editedRowIndices = {};
  
  // Transaction type for file naming
  String _transactionType = '';
  
  // Dropdown options for Payout Status
  final Map<String, String> _payoutStatusOptions = {
    '1': 'SUCCESS',
    '2': 'FAILED', 
    '3': 'PROCESSING',
    '4': 'REJECTED'
  };

  // Check if a string is numeric
  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    try {
      double.parse(str);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Initialize editable columns
  void _initializeEditableColumns() {
    _editableColumns.clear();
    if (_csvHeaders == null) return;
    
    final editableColumnNames = [
      'processed amount',
      'processed currency', 
      'target amount',
      'target currency',
      'payout status'
    ];
    
    print('Initializing editable columns from headers: ${_csvHeaders!.join(", ")}');
    
    for (int i = 0; i < _csvHeaders!.length; i++) {
      final headerLower = _csvHeaders![i].toLowerCase().trim();
      print('  Checking header $i: "$headerLower"');
      
      for (String editableColumn in editableColumnNames) {
        if (headerLower.contains(editableColumn)) {
          _editableColumns[editableColumn] = i;
          print('    Found $editableColumn at index $i');
          break;
        }
      }
    }
    
    print('Final editable columns mapping: $_editableColumns');
    
    // Create column order with editable columns first
    _createColumnOrder();
  }
  
  // Create column order with input columns first, then editable columns
  void _createColumnOrder() {
    if (_csvHeaders == null) return;
    
    List<int> inputAmountIndices = [];
    List<int> inputCurrencyIndices = [];
    List<int> editableIndices = [];
    List<int> nonEditableIndices = [];
    
    // Separate columns by type
    for (int i = 0; i < _csvHeaders!.length; i++) {
      final headerLower = _csvHeaders![i].toLowerCase().trim();
      
      if (headerLower.contains('input') && headerLower.contains('amount')) {
        inputAmountIndices.add(i);
      } else if (headerLower.contains('input') && headerLower.contains('currency')) {
        inputCurrencyIndices.add(i);
      } else if (_isColumnEditable(i)) {
        editableIndices.add(i);
      } else {
        nonEditableIndices.add(i);
      }
    }
    
    // Sort editable columns in preferred order
    final preferredEditableOrder = [
      'processed amount',
      'processed currency', 
      'target amount',
      'target currency',
      'payout status'
    ];
    
    editableIndices.sort((a, b) {
      String headerA = _csvHeaders![a].toLowerCase().trim();
      String headerB = _csvHeaders![b].toLowerCase().trim();
      
      int indexA = preferredEditableOrder.length;
      int indexB = preferredEditableOrder.length;
      
      for (int i = 0; i < preferredEditableOrder.length; i++) {
        if (headerA.contains(preferredEditableOrder[i])) {
          indexA = i;
        }
        if (headerB.contains(preferredEditableOrder[i])) {
          indexB = i;
        }
      }
      
      return indexA.compareTo(indexB);
    });
    
    // Combine: input amount, input currency, then editable columns, then non-editable
    _columnOrder = [
      ...inputAmountIndices,
      ...inputCurrencyIndices, 
      ...editableIndices, 
      ...nonEditableIndices
    ];
    
    // Create reordered headers
    _reorderedHeaders = _columnOrder!.map((index) => _csvHeaders![index]).toList();
  }
  
  // Check if a column is editable
  bool _isColumnEditable(int columnIndex) {
    return _editableColumns.values.contains(columnIndex);
  }
  
  // Check if a column is dropdown type
  bool _isDropdownColumn(int columnIndex) {
    return _editableColumns['payout status'] == columnIndex;
  }
  
  // Check if a column is an input column (read-only but highlighted)
  bool _isInputColumn(int columnIndex) {
    if (_csvHeaders == null || columnIndex >= _csvHeaders!.length) return false;
    final headerLower = _csvHeaders![columnIndex].toLowerCase().trim();
    return headerLower.contains('input') && 
           (headerLower.contains('amount') || headerLower.contains('currency'));
  }
  
  // Check if a column is auto-synced (processed amount/currency)
  bool _isAutoSyncedColumn(int columnIndex) {
    return _editableColumns['processed amount'] == columnIndex ||
           _editableColumns['processed currency'] == columnIndex;
  }
  
  // Check if a column is target currency (needs alphabet-only input)
  bool _isTargetCurrencyColumn(int columnIndex) {
    return _editableColumns['target currency'] == columnIndex;
  }
  
  // Map common status text to dropdown values
  String _mapStatusToDropdownValue(String statusText) {
    final lowerStatus = statusText.toLowerCase().trim();
    
    // Direct number mapping
    if (_payoutStatusOptions.containsKey(statusText.trim())) {
      return statusText.trim();
    }
    
    // Text to number mapping
    if (lowerStatus.contains('success') || lowerStatus == 'completed' || lowerStatus == 'paid') {
      return '1';
    } else if (lowerStatus.contains('fail') || lowerStatus == 'error') {
      return '2';
    } else if (lowerStatus.contains('processing') || lowerStatus == 'pending') {
      return '3';
    } else if (lowerStatus.contains('reject') || lowerStatus == 'cancelled') {
      return '4';
    }
    
    // Default fallback
    return '1';
  }
  
  // Get reordered row data
  List<String> _getReorderedRow(List<String> originalRow) {
    if (_columnOrder == null) return originalRow;
    
    List<String> reorderedRow = [];
    for (int originalIndex in _columnOrder!) {
      if (originalIndex < originalRow.length) {
        reorderedRow.add(originalRow[originalIndex]);
      } else {
        reorderedRow.add('');
      }
    }
    return reorderedRow;
  }
  
  // Get original column index from reordered index
  int _getOriginalColumnIndex(int reorderedIndex) {
    if (_columnOrder == null || reorderedIndex >= _columnOrder!.length) {
      return reorderedIndex;
    }
    return _columnOrder![reorderedIndex];
  }
  
  // Start editing a cell
  void _startEditing(int rowIndex, int columnIndex, String currentValue) {
    final key = '${rowIndex}_$columnIndex';
    
    print('START EDITING: Row $rowIndex, Column $columnIndex');
    print('  Header: ${_csvHeaders![columnIndex]}');
    print('  Current value: "$currentValue"');
    print('  Column index is ALREADY the original index from UI click mapping');
    
    setState(() {
      _isEditing[key] = true;
      if (_isDropdownColumn(columnIndex)) {
        // For dropdown columns, map the current value to a valid dropdown option
        _dropdownValues[key] = _mapStatusToDropdownValue(currentValue);
      } else {
        // For text columns, create text controller
        _editControllers[key] = TextEditingController(text: currentValue);
      }
    });
  }
  
  // Save cell edit
  void _saveEdit(int rowIndex, int columnIndex) {
    final key = '${rowIndex}_$columnIndex';
    if (_csvData != null) {
      setState(() {
        final oldValue = _csvData![rowIndex][columnIndex];
        
        if (_isDropdownColumn(columnIndex)) {
          // Save dropdown value
          final dropdownValue = _dropdownValues[key] ?? '';
          _csvData![rowIndex][columnIndex] = dropdownValue;
          _dropdownValues.remove(key);
          print('DROPDOWN SAVE: Payout Status');
          print('  Dropdown value selected: "$dropdownValue"');
          print('  Mapping: ${_payoutStatusOptions[dropdownValue] ?? "NOT FOUND"}');
        } else {
          // Save text field value
          if (_editControllers[key] != null) {
            _csvData![rowIndex][columnIndex] = _editControllers[key]!.text;
            _editControllers[key]?.dispose();
            _editControllers.remove(key);
          }
        }
        
        final newValue = _csvData![rowIndex][columnIndex];
        print('SAVE EDIT: Row $rowIndex, Column $columnIndex (${_csvHeaders![columnIndex]})');
        print('  Old value: "$oldValue"');
        print('  New value: "$newValue"');
        print('  Full row after edit: ${_csvData![rowIndex].join(" | ")}');
        
        _isEditing[key] = false;
        
        // Track that this row has been edited
        _editedRowIndices.add(rowIndex);
        print('  Edited row indices now: $_editedRowIndices');
        
        // Auto-sync processed values with target values
        _syncProcessedWithTarget(rowIndex, columnIndex);
        
        // Update filtered data
        _filterData();
      });
    }
  }
  
  // Sync processed amount/currency with target amount/currency
  void _syncProcessedWithTarget(int rowIndex, int columnIndex) {
    if (_csvData == null || rowIndex >= _csvData!.length) return;
    
    final headerLower = _csvHeaders![columnIndex].toLowerCase().trim();
    final editedValue = _csvData![rowIndex][columnIndex];
    
    print('Syncing row $rowIndex, column $columnIndex (${_csvHeaders![columnIndex]}) with value: "$editedValue"');
    
    // If target amount was edited, copy to processed amount
    if (headerLower.contains('target') && headerLower.contains('amount')) {
      final processedAmountIndex = _editableColumns['processed amount'];
      if (processedAmountIndex != null && processedAmountIndex < _csvData![rowIndex].length) {
        final oldProcessedValue = _csvData![rowIndex][processedAmountIndex];
        _csvData![rowIndex][processedAmountIndex] = editedValue;
        print('  Target amount sync: "$oldProcessedValue" -> "$editedValue" (processed amount index: $processedAmountIndex)');
      }
    }
    
    // If target currency was edited, copy to processed currency (also ensure uppercase)
    if (headerLower.contains('target') && headerLower.contains('currency')) {
      final processedCurrencyIndex = _editableColumns['processed currency'];
      if (processedCurrencyIndex != null && processedCurrencyIndex < _csvData![rowIndex].length) {
        final oldProcessedValue = _csvData![rowIndex][processedCurrencyIndex];
        final newValue = editedValue.toUpperCase();
        _csvData![rowIndex][processedCurrencyIndex] = newValue;
        print('  Target currency sync: "$oldProcessedValue" -> "$newValue" (processed currency index: $processedCurrencyIndex)');
      }
    }
  }
   
   // Perform initial sync of all processed values with target values
   void _performInitialSync() {
     if (_csvData == null) return;
     
     final processedAmountIndex = _editableColumns['processed amount'];
     final processedCurrencyIndex = _editableColumns['processed currency'];
     final targetAmountIndex = _editableColumns['target amount'];
     final targetCurrencyIndex = _editableColumns['target currency'];
     
     // Also find input amount and currency indices to copy from
     int? inputAmountIndex;
     int? inputCurrencyIndex;
     
     for (int i = 0; i < _csvHeaders!.length; i++) {
       final headerLower = _csvHeaders![i].toLowerCase().trim();
       if (headerLower.contains('input') && headerLower.contains('amount')) {
         inputAmountIndex = i;
       } else if (headerLower.contains('input') && headerLower.contains('currency')) {
         inputCurrencyIndex = i;
       }
     }
     
     print('Initial sync - Column indices:');
     print('  Input Amount: $inputAmountIndex');
     print('  Input Currency: $inputCurrencyIndex');
     print('  Processed Amount: $processedAmountIndex');
     print('  Processed Currency: $processedCurrencyIndex');
     print('  Target Amount: $targetAmountIndex');
     print('  Target Currency: $targetCurrencyIndex');
     
     for (int rowIndex = 0; rowIndex < _csvData!.length; rowIndex++) {
       final row = _csvData![rowIndex];
       
       print('  Row $rowIndex original values:');
       if (inputAmountIndex != null && inputAmountIndex < row.length) {
         print('    Original Input Amount: "${row[inputAmountIndex]}"');
       }
       if (inputCurrencyIndex != null && inputCurrencyIndex < row.length) {
         print('    Original Input Currency: "${row[inputCurrencyIndex]}"');
       }
       if (processedAmountIndex != null && processedAmountIndex < row.length) {
         print('    Original Processed Amount: "${row[processedAmountIndex]}"');
       }
       if (targetAmountIndex != null && targetAmountIndex < row.length) {
         print('    Original Target Amount: "${row[targetAmountIndex]}"');
       }
       if (processedCurrencyIndex != null && processedCurrencyIndex < row.length) {
         print('    Original Processed Currency: "${row[processedCurrencyIndex]}"');
       }
       if (targetCurrencyIndex != null && targetCurrencyIndex < row.length) {
         print('    Original Target Currency: "${row[targetCurrencyIndex]}"');
       }
       
       // First, copy from Input fields to Target fields if Target fields are empty
       // DO NOT copy Input Amount to Target Amount - let users enter manually
       // DO NOT copy Input Currency to Target Currency - let users enter manually
       // Removed: All Input -> Target auto-copy logic
       
       // Handle target amount to processed amount sync (will be empty initially)
       if (targetAmountIndex != null && processedAmountIndex != null &&
           targetAmountIndex < row.length && processedAmountIndex < row.length) {
         final targetValue = row[targetAmountIndex].trim();
         final processedValue = row[processedAmountIndex].trim();
         
         // Only sync if one field has a value and the other doesn't
         if (targetValue.isNotEmpty && processedValue.isEmpty) {
           // Target has value, processed is empty - copy to processed
           row[processedAmountIndex] = targetValue;
           print('    Amount sync: Target "$targetValue" -> Processed (was empty)');
         } else if (processedValue.isNotEmpty && targetValue.isEmpty) {
           // Processed has value, target is empty - copy to target
           row[targetAmountIndex] = processedValue;
           print('    Amount sync: Processed "$processedValue" -> Target (was empty)');
         } else if (targetValue.isNotEmpty && processedValue.isNotEmpty) {
           // Both have values - keep target as the source of truth
           row[processedAmountIndex] = targetValue;
           print('    Amount sync: Both had values, keeping Target "$targetValue" in both');
         }
         // If both are empty, do nothing
       }
       
       // Handle target currency to processed currency sync
       if (targetCurrencyIndex != null && processedCurrencyIndex != null &&
           targetCurrencyIndex < row.length && processedCurrencyIndex < row.length) {
         final targetValue = row[targetCurrencyIndex].trim();
         final processedValue = row[processedCurrencyIndex].trim();
         
         // Only sync if one field has a value and the other doesn't
         if (targetValue.isNotEmpty && processedValue.isEmpty) {
           // Target has value, processed is empty - copy to processed (ensure uppercase)
           row[processedCurrencyIndex] = targetValue.toUpperCase();
           print('    Currency sync: Target "$targetValue" -> Processed "${targetValue.toUpperCase()}" (was empty)');
         } else if (processedValue.isNotEmpty && targetValue.isEmpty) {
           // Processed has value, target is empty - copy to target (ensure uppercase)
           final upperValue = processedValue.toUpperCase();
           row[targetCurrencyIndex] = upperValue;
           row[processedCurrencyIndex] = upperValue; // Ensure both are uppercase
           print('    Currency sync: Processed "$processedValue" -> Target "$upperValue" (was empty)');
         } else if (targetValue.isNotEmpty && processedValue.isNotEmpty) {
           // Both have values - ensure both are uppercase and synchronized
           final upperValue = targetValue.toUpperCase();
           row[targetCurrencyIndex] = upperValue;
           row[processedCurrencyIndex] = upperValue;
           print('    Currency sync: Both had values, standardized to "$upperValue"');
         }
         // If both are empty, do nothing
       }
       
       print('  Row $rowIndex final values:');
       if (processedAmountIndex != null && processedAmountIndex < row.length) {
         print('    Final Processed Amount: "${row[processedAmountIndex]}"');
       }
       if (targetAmountIndex != null && targetAmountIndex < row.length) {
         print('    Final Target Amount: "${row[targetAmountIndex]}"');
       }
       if (processedCurrencyIndex != null && processedCurrencyIndex < row.length) {
         print('    Final Processed Currency: "${row[processedCurrencyIndex]}"');
       }
       if (targetCurrencyIndex != null && targetCurrencyIndex < row.length) {
         print('    Final Target Currency: "${row[targetCurrencyIndex]}"');
       }
     }
     
     print('Initial sync completed for ${_csvData!.length} rows');
   }
   
   // Cancel cell edit
  void _cancelEdit(int rowIndex, int columnIndex) {
    final key = '${rowIndex}_$columnIndex';
    setState(() {
      _isEditing[key] = false;
      if (_isDropdownColumn(columnIndex)) {
        _dropdownValues.remove(key);
      } else {
        _editControllers[key]?.dispose();
        _editControllers.remove(key);
      }
    });
  }

  // Filter data based on Transaction ID or Publisher Transaction ID
  void _filterData() {
    if (_csvData == null || _csvHeaders == null) return;
    
    if (_filterText.isEmpty) {
      _filteredData = _csvData;
      return;
    }
    
    // Find column indices for Transaction ID and Publisher Transaction ID
    if (_transactionIdIndex == null || _publisherTransactionIdIndex == null) {
      for (int i = 0; i < _csvHeaders!.length; i++) {
        final header = _csvHeaders![i].toLowerCase().trim();
        
        // More flexible header detection
        if ((header.contains('transaction') && header.contains('id')) && 
            !header.contains('publisher')) {
          _transactionIdIndex = i;
        } else if (header.contains('publisher') && 
                   header.contains('transaction') && 
                   header.contains('id')) {
          _publisherTransactionIdIndex = i;
        }
      }
    }
    
    // Filter the data
    final searchText = _filterText.toLowerCase().trim();
    
    _filteredData = _csvData!.where((row) {
      bool matchFound = false;
      
      // First try the specific Transaction ID columns if found
      if (_transactionIdIndex != null && _transactionIdIndex! < row.length) {
        final cellValue = row[_transactionIdIndex!].toLowerCase().trim();
        if (cellValue.contains(searchText)) {
          matchFound = true;
        }
      }
      
      if (_publisherTransactionIdIndex != null && _publisherTransactionIdIndex! < row.length) {
        final cellValue = row[_publisherTransactionIdIndex!].toLowerCase().trim();
        if (cellValue.contains(searchText)) {
          matchFound = true;
        }
      }
      
      // If no match yet, search ALL columns for the ID (fallback)
      if (!matchFound) {
        for (int i = 0; i < row.length && i < _csvHeaders!.length; i++) {
          final cellValue = row[i].toLowerCase().trim();
          
          if (cellValue.contains(searchText)) {
            matchFound = true;
            break;
          }
        }
      }
      
      return matchFound;
    }).toList();
  }

  // Parse CSV content into structured data
  void _parseCsvContent(String content) {
    try {
      final lines = content.split('\n');
      if (lines.isEmpty) return;

      // Parse headers (first line)
      _csvHeaders = _parseCsvLine(lines[0]);
      print('Parsed CSV headers: ${_csvHeaders!.join(", ")}');
      
      // Reset filter indices when new data is loaded
      _transactionIdIndex = null;
      _publisherTransactionIdIndex = null;
      _filterText = '';
      
      // Parse data rows
      _csvData = [];
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) {
          final row = _parseCsvLine(lines[i]);
          if (row.isNotEmpty) {
            _csvData!.add(row);
            
            // Debug first few rows to see if amounts are preserved
            if (i <= 3) {
              print('Row $i parsed: ${row.join(" | ")}');
            }
          }
        }
      }
      
      print('Parsed ${_csvData!.length} data rows');
      
      // Initialize filtered data with all data
      _filteredData = _csvData;
      
      // Initialize editable columns
      _initializeEditableColumns();
      
      // Show sample data for amount columns after column detection
      if (_csvData!.isNotEmpty) {
        final processedAmountIndex = _editableColumns['processed amount'];
        final targetAmountIndex = _editableColumns['target amount'];
        final payoutStatusIndex = _editableColumns['payout status'];
        
        print('Sample data for amount columns:');
        for (int rowIndex = 0; rowIndex < math.min(3, _csvData!.length); rowIndex++) {
          final row = _csvData![rowIndex];
          if (processedAmountIndex != null && processedAmountIndex < row.length) {
            print('  Row $rowIndex - Processed Amount (index $processedAmountIndex): "${row[processedAmountIndex]}"');
          }
          if (targetAmountIndex != null && targetAmountIndex < row.length) {
            print('  Row $rowIndex - Target Amount (index $targetAmountIndex): "${row[targetAmountIndex]}"');
          }
          if (payoutStatusIndex != null && payoutStatusIndex < row.length) {
            print('  Row $rowIndex - Original Payout Status (index $payoutStatusIndex): "${row[payoutStatusIndex]}"');
          }
        }
      }
      
      // Initial sync of processed values with target values
      _performInitialSync();
    } catch (e) {
      print('Error parsing CSV: $e');
    }
  }

  // Parse a single CSV line, handling quoted fields
  List<String> _parseCsvLine(String line) {
    List<String> result = [];
    String current = '';
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      String char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    // Add the last field
    result.add(current.trim());
    
    // Debug the first few lines parsed
    if (result.length > 15) { // Only debug if it looks like a data row (not header)
      bool hasAmountData = false;
      for (String field in result) {
        if (field.contains('.') && double.tryParse(field) != null) {
          hasAmountData = true;
          break;
        }
      }
      
      if (hasAmountData) {
        print('CSV line parsing debug:');
        print('  Input: ${line.length > 100 ? line.substring(0, 100) + "..." : line}');
        print('  Parsed into ${result.length} fields');
        for (int i = 0; i < result.length; i++) {
          if (result[i].isNotEmpty && double.tryParse(result[i]) != null) {
            print('    Field $i (numeric): "${result[i]}"');
          }
        }
      }
    }
    
    return result;
  }

  // VPN connection check - JavaScript fetch with no-cors mode
  Future<bool> _checkVpnConnection() async {
    try {
      // Use JavaScript fetch with no-cors mode to bypass CORS restrictions
      final result = await html.window.fetch(
        'https://payout-scheduler.codapay.net/internal/scheduler/email-workflow/check-new-email',
        {
          'method': 'POST',
          'mode': 'no-cors', // This bypasses CORS but limits response access
        }
      );
      
      // In no-cors mode, we can't read the status code directly
      // But if the request completes without error, it means the endpoint is reachable
      // and likely the VPN is connected (since this is an internal endpoint)
      print('VPN check fetch completed - assuming VPN is connected');
      return true;
    } catch (e) {
      print('VPN check failed: $e');
      return false;
    }
  }

  // Call check-new-email API client-side with no-cors
  Future<void> _callCheckNewEmailApi() async {
    try {
      print('Calling check-new-email API...');
      await html.window.fetch(
        'https://payout-scheduler.codapay.net/internal/scheduler/email-workflow/check-new-email',
        {
          'method': 'POST',
          'mode': 'no-cors',
        }
      );
      print('API call completed successfully');
    } catch (e) {
      print('API call failed: $e');
    }
  }

  // Helper function to create HTTP options for fetch API
  Map<String, dynamic> createHttpOptions({required String method, required String mode}) {
    return {
      'method': method,
      'mode': mode,
      'credentials': 'include',
      'headers': {
        'Content-Type': 'application/json',
      },
    };
  }

  // Call wallet unfinished report API
  Future<void> _callWalletUnfinishedReportApi() async {
    try {
      // Use fetch API with no-cors mode
      await html.window.fetch(
        'https://payout-scheduler.codapay.net/internal/scheduler/email-workflow/send-wallet-unfinished-report',
        createHttpOptions(method: 'POST', mode: 'no-cors'),
      );
      print('Wallet Report API called successfully');
      
      // Always show success since no-cors mode doesn't return status
      {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Wallet Unfinished Report sent successfully',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      print('Error calling Wallet Report API: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error sending Wallet Report: $error',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      rethrow;
    }
  }

  // Call bank transfer unfinished report API
  Future<void> _callBankTransferUnfinishedReportApi() async {
    try {
      // Use fetch API with no-cors mode
      await html.window.fetch(
        'https://payout-scheduler.codapay.net/internal/scheduler/email-workflow/send-bank-transfer-unfinished-report',
        createHttpOptions(method: 'POST', mode: 'no-cors'),
      );
      print('Bank Transfer Report API called successfully');
      
      // Always show success since no-cors mode doesn't return status
      {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bank Transfer Unfinished Report sent successfully',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      print('Error calling Bank Transfer Report API: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error sending Bank Transfer Report: $error',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      rethrow;
    }
  }

  // Show VPN connection dialog
  void _showVpnDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('VPN Required'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please connect to VPN before using this application.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. Connect to your VPN'),
              Text('2. Click "Recheck Connection" below'),
              Text('3. Once connected, you can select files'),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                // Show loading
                final navigator = Navigator.of(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Checking VPN connection...'),
                        ],
                      ),
                    );
                  },
                );

                // Check VPN
                final isConnected = await _checkVpnConnection();
                
                // Close loading dialog
                navigator.pop();
                
                if (isConnected) {
                  // Close VPN dialog and proceed with file upload
                  navigator.pop();
                  _proceedWithFileUpload();
                } else {
                  // Show error
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('VPN connection failed. Please check your connection and try again.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Recheck Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // File upload handler with VPN check
  void _handleFileUpload() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Checking VPN connection...'),
            ],
          ),
        );
      },
    );

    // Check VPN connection first
    final isVpnConnected = await _checkVpnConnection();
    
    // Close loading dialog
    Navigator.of(context).pop();

    if (isVpnConnected) {
      // VPN is connected, proceed with file upload
      _proceedWithFileUpload();
    } else {
      // VPN not connected, show VPN dialog
      _showVpnDialog();
    }
  }

  // Proceed with actual file upload
  void _proceedWithFileUpload() {
    final input = html.FileUploadInputElement()..accept = '.csv,.zip';
    input.click();

    input.onChange.listen((event) {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        setState(() {
          _selectedFileName = file.name;
          _processingStatus = 'Processing file...';
          _csvData = null;
          _csvHeaders = null;
        });

        _processFile(file);
      }
    });
  }

  // Process uploaded file
  Future<void> _processFile(html.File file) async {
    try {
      final reader = html.FileReader();
      
      reader.onLoad.listen((event) {
        final result = reader.result;
        if (result is Uint8List) {
          _handleFileContent(result, file.name);
        }
      });

      reader.readAsArrayBuffer(file);
    } catch (e) {
      setState(() {
        _processingStatus = 'Error processing file: $e';
        _isFileProcessed = false;
      });
    }
  }

  // Handle file content based on file type
  void _handleFileContent(Uint8List bytes, String fileName) {
    if (fileName.toLowerCase().endsWith('.zip')) {
      _processZipFile(bytes, fileName);
    } else if (fileName.toLowerCase().endsWith('.csv')) {
      _processCsvFile(bytes, fileName);
    } else {
      setState(() {
        _processingStatus = 'Unsupported file type. Please upload CSV or ZIP files.';
        _isFileProcessed = false;
      });
    }
  }

  // Process ZIP file
  void _processZipFile(Uint8List bytes, String fileName) {
    setState(() {
      _processingStatus = 'Extracting ZIP file with password...';
    });

    try {
      // Create archive with password
      final archive = ZipDecoder().decodeBytes(bytes, password: 'P@ssw0rd');
      
      // Look for CSV files in the archive
      final csvFiles = archive.where((file) => file.name.toLowerCase().endsWith('.csv')).toList();
      
      if (csvFiles.isEmpty) {
        setState(() {
          _processingStatus = 'No CSV files found in ZIP archive.';
          _isFileProcessed = false;
        });
        return;
      }

      // Use the first CSV file found
      final csvFile = csvFiles.first;
      final csvContent = String.fromCharCodes(csvFile.content as List<int>);
      
      setState(() {
        _fileContent = csvContent;
        _processingStatus = 'ZIP file extracted successfully! Found CSV: ${csvFile.name}';
        _isFileProcessed = true;
      });
      
      _parseCsvContent(csvContent);
    } catch (e) {
      setState(() {
        _processingStatus = 'Error extracting ZIP file: $e';
        _isFileProcessed = false;
      });
    }
  }

  // Process CSV file
  void _processCsvFile(Uint8List bytes, String fileName) {
    setState(() {
      _processingStatus = 'Processing CSV file...';
    });

    try {
      final content = String.fromCharCodes(bytes);
      setState(() {
        _fileContent = content;
        _processingStatus = 'CSV file loaded successfully!';
        _isFileProcessed = true;
      });
      
      _parseCsvContent(content);
    } catch (e) {
      setState(() {
        _processingStatus = 'Error reading CSV file: $e';
        _isFileProcessed = false;
      });
    }
  }


  
  // Convert payout status number to text
  String _convertPayoutStatusToText(String status) {
    final trimmedStatus = status.trim();
    print('Converting payout status: "$trimmedStatus" -> "${_payoutStatusOptions[trimmedStatus] ?? trimmedStatus}"');
    return _payoutStatusOptions[trimmedStatus] ?? trimmedStatus;
  }
  
  // Generate CSV content with only edited rows
  String _generateEditedCsvContent() {
    if (_csvHeaders == null || _csvData == null || _editedRowIndices.isEmpty) {
      return '';
    }
    
    List<String> csvLines = [];
    
    // Add header
    csvLines.add(_csvHeaders!.map((header) => '"$header"').join(','));
    
    // Find column indices
    final payoutStatusIndex = _editableColumns['payout status'];
    final processedAmountIndex = _editableColumns['processed amount'];
    final targetAmountIndex = _editableColumns['target amount'];
    final processedCurrencyIndex = _editableColumns['processed currency'];
    final targetCurrencyIndex = _editableColumns['target currency'];
    
    print('Generating edited CSV content:');
    print('  Headers: ${_csvHeaders!.join(", ")}');
    print('  Edited row indices: $_editedRowIndices');
    print('  Payout status index: $payoutStatusIndex');
    print('  Editable columns: $_editableColumns');
    print('  Current _csvData state check:');
    
    // Add only edited rows
    for (int rowIndex in _editedRowIndices) {
      if (rowIndex < _csvData!.length) {
        // Get the CURRENT state of the row from _csvData (this should include all edits)
        final row = List<String>.from(_csvData![rowIndex]);
        
        print('  Row $rowIndex CURRENT state: ${row.join(" | ")}');
        
        // Show specific currency and amount values from current state
        if (processedCurrencyIndex != null && processedCurrencyIndex < row.length) {
          print('    CURRENT Processed Currency (index $processedCurrencyIndex): "${row[processedCurrencyIndex]}"');
        }
        if (targetCurrencyIndex != null && targetCurrencyIndex < row.length) {
          print('    CURRENT Target Currency (index $targetCurrencyIndex): "${row[targetCurrencyIndex]}"');
        }
        if (processedAmountIndex != null && processedAmountIndex < row.length) {
          print('    CURRENT Processed Amount (index $processedAmountIndex): "${row[processedAmountIndex]}"');
        }
        if (targetAmountIndex != null && targetAmountIndex < row.length) {
          print('    CURRENT Target Amount (index $targetAmountIndex): "${row[targetAmountIndex]}"');
        }
        
        // IMPORTANT: Override Processed Amount/Currency with Target Amount/Currency for export
        // This ensures user's Target edits take precedence in the exported file
        if (targetAmountIndex != null && processedAmountIndex != null && 
            targetAmountIndex < row.length && processedAmountIndex < row.length) {
          final targetAmount = row[targetAmountIndex].trim();
          if (targetAmount.isNotEmpty) {
            row[processedAmountIndex] = targetAmount;
            print('    EXPORT OVERRIDE: Using Target Amount "$targetAmount" for Processed Amount');
          }
        }
        
        if (targetCurrencyIndex != null && processedCurrencyIndex != null && 
            targetCurrencyIndex < row.length && processedCurrencyIndex < row.length) {
          final targetCurrency = row[targetCurrencyIndex].trim();
          if (targetCurrency.isNotEmpty) {
            row[processedCurrencyIndex] = targetCurrency.toUpperCase();
            print('    EXPORT OVERRIDE: Using Target Currency "$targetCurrency" for Processed Currency');
          }
        }
        
        // Convert payout status from number to text
        if (payoutStatusIndex != null && payoutStatusIndex < row.length) {
          final originalStatus = row[payoutStatusIndex];
          row[payoutStatusIndex] = _convertPayoutStatusToText(row[payoutStatusIndex]);
          print('    Converted payout status: $originalStatus -> ${row[payoutStatusIndex]}');
        }
        
        print('  Row $rowIndex FINAL for CSV (after export overrides): ${row.join(" | ")}');
        
        final csvRow = row.map((cell) => '"$cell"').join(',');
        csvLines.add(csvRow);
      }
    }
    
    final result = csvLines.join('\n');
    print('Generated CSV content (${csvLines.length} lines):');
    print('--- CSV START ---');
    print(result);
    print('--- CSV END ---');
    return result;
  }
  

  
  // Download ZIP file from base64 content
  void _downloadZipFile(String base64Content, String fileName) {
    final bytes = base64Decode(base64Content);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    
    html.Url.revokeObjectUrl(url);
  }
  

  
  // Show transaction type selection dialog for email
  void _showEmailTransactionTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Transaction Type for Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('1. Wallet'),
                leading: Radio<String>(
                  value: '_WALLET',
                  groupValue: _transactionType,
                  onChanged: (String? value) {
                    setState(() {
                      _transactionType = value ?? '';
                    });
                    Navigator.of(context).pop();
                    _showEmailFileNameDialog();
                  },
                ),
              ),
              ListTile(
                title: const Text('2. Bank Transfer'),
                leading: Radio<String>(
                  value: '_BANK_TRANSFER',
                  groupValue: _transactionType,
                  onChanged: (String? value) {
                    setState(() {
                      _transactionType = value ?? '';
                    });
                    Navigator.of(context).pop();
                    _showEmailFileNameDialog();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Show file name input dialog for email
  void _showEmailFileNameDialog() {
    final TextEditingController fileNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter File Name for Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fileNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., MyData',
                  labelText: 'File Name',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Files to be emailed:\n'
                '• approved_${fileNameController.text.isEmpty ? "filename" : fileNameController.text}$_transactionType.zip\n'
                '• ${fileNameController.text.isEmpty ? "filename" : fileNameController.text}$_transactionType.zip',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (fileNameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _sendEmailWithFiles(fileNameController.text.trim());
                }
              },
              child: const Text('Send Email'),
            ),
          ],
        );
      },
    );
  }
  
  // Send email with generated ZIP files - step by step process
  Future<void> _sendEmailWithFiles(String baseName) async {
    if (_editedRowIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No edited rows to send via email')),
      );
      return;
    }
    
    try {
      // Generate CSV content with user's selected payout status
      final originalContent = _generateEditedCsvContent();
      
      print('=== EMAIL STEP-BY-STEP PROCESS ===');
      print('To: payout-qa-internal@codapayments.com');
      print('Subject: Sandbox Txn Status Update');
      print('Password: P@ssw0rd');
      print('===================================');
      
      // Show full-screen progress overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'Sending Emails',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildProgressStep(1, 'Sending approved ZIP file...', true),
                    _buildProgressStep(2, 'Waiting for API (10s)', false),
                    _buildProgressStep(3, 'Sending original ZIP file...', false),
                    _buildProgressStep(4, 'Final API call (10s)', false),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Process Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                                                      Text(
                              'Total time: ~40 seconds\nDo not close this window',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      print('Step 1: Sending approved ZIP file...');
      final approvedResponse = await http.post(
        Uri.parse('https://sendemail-amxcplfi6q-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'originalCsv': originalContent,
          'fileName': baseName,
          'transactionType': _transactionType,
          'emailType': 'approved',
        }),
      );

      if (approvedResponse.statusCode != 200) {
        Navigator.of(context).pop(); // Close progress dialog
        throw Exception('Failed to send approved email: ${approvedResponse.body}');
      }
      
      // Download approved ZIP file
      final approvedData = json.decode(approvedResponse.body);
      if (approvedData['zipContent'] != null) {
        _downloadZipFile(approvedData['zipContent'], approvedData['fileName']);
      }
      print('✅ Approved email sent successfully');

      // Update progress dialog
      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'Sending Emails',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProgressStep(1, 'Approved ZIP sent ✓', true, isDone: true),
                      _buildProgressStep(2, 'Waiting for API (20s)', true),
                      _buildProgressStep(3, 'Sending original ZIP file...', false),
                      _buildProgressStep(4, 'Final API call (15s)', false),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Process Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Time remaining: ~30 seconds\nDo not close this window',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      print('Step 2: Waiting 10 seconds...');
      await Future.delayed(const Duration(seconds: 10));
      print('Step 2: Calling check-new-email API...');
      await _callCheckNewEmailApi();

      // Update progress dialog
      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'Sending Emails',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProgressStep(1, 'Approved ZIP sent ✓', true, isDone: true),
                      _buildProgressStep(2, 'API call completed ✓', true, isDone: true),
                      _buildProgressStep(3, 'Sending original ZIP file...', true),
                      _buildProgressStep(4, 'Final API call (15s)', false),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Process Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Time remaining: ~20 seconds\nDo not close this window',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      // Step 3: Send original ZIP
      print('Step 3: Waiting 10 seconds...');
      await Future.delayed(const Duration(seconds: 10));
      print('Step 3: Sending original ZIP file...');
      final originalResponse = await http.post(
        Uri.parse('https://sendemail-amxcplfi6q-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'originalCsv': originalContent,
          'fileName': baseName,
          'transactionType': _transactionType,
          'emailType': 'original',
        }),
      );

      if (originalResponse.statusCode != 200) {
        Navigator.of(context).pop(); // Close progress dialog
        throw Exception('Failed to send original email: ${originalResponse.body}');
      }
      
      // Download original ZIP file
      final originalData = json.decode(originalResponse.body);
      if (originalData['zipContent'] != null) {
        _downloadZipFile(originalData['zipContent'], originalData['fileName']);
      }
      print('✅ Original email sent successfully');

      // Update progress dialog for final step
      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'Sending Emails',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProgressStep(1, 'Approved ZIP sent ✓', true, isDone: true),
                      _buildProgressStep(2, 'API call completed ✓', true, isDone: true),
                      _buildProgressStep(3, 'Original ZIP sent ✓', true, isDone: true),
                      _buildProgressStep(4, 'Final API call (15s)', true),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Process Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Time remaining: ~10 seconds\nDo not close this window',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      // Step 4: Final API call
      print('Step 4: Waiting 10 seconds...');
      await Future.delayed(const Duration(seconds: 10));
      print('Step 4: Final API call...');
      await _callCheckNewEmailApi();

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Text(
                      'Process Completed Successfully!',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '✅ Approved ZIP sent (all status = APPROVED)\n'
                  '✅ Original ZIP sent (your selected status)\n'
                  '✅ ZIP files downloaded to your computer\n'
                  '✅ Transaction Status updated to your selected status\n\n',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      print('=== PROCESS COMPLETED SUCCESSFULLY ===');

    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in email process: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      print('❌ Error in email process: $error');
    }
  }





  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Sophisticated Black Background with Subtle Patterns
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _FloatingParticlesPainter(
                      particles: _particles,
                      animation: _floatingAnimation,
                    ),
                    child: Container(),
                  );
                },
              ),
            ),
            
            // Main Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Admin Section
                          _buildAdminSection(),
                          
                          // Premium Hero Section
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(48),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.1),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Premium Icon with Glow Effect
                                    AnimatedBuilder(
                                      animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: Container(
                                            padding: const EdgeInsets.all(32),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white.withOpacity(0.1 * _glowAnimation.value),
                                                  blurRadius: 20 * _glowAnimation.value,
                                                  spreadRadius: 2 * _glowAnimation.value,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.upload_file,
                                              size: 64,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                      'PAYOUT INTERNAL TOOL',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                        fontSize: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'UPLOAD AND PROCESS ZIP FILES FOR TRANSACTION EDITING',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.black.withOpacity(0.7),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                  
                          // Premium File Upload Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.file_upload,
                                        size: 24,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'FILE UPLOAD',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                        letterSpacing: 1.5,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: Container(
                                    width: 400,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black.withOpacity(0.2),
                                        style: BorderStyle.solid,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.black.withOpacity(0.02),
                                    ),
                                    child: InkWell(
                                      onTap: _handleFileUpload,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 48,
                                            color: Colors.black.withOpacity(0.6),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'CLICK TO UPLOAD ZIP FILE',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black.withOpacity(0.7),
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'SUPPORTS PASSWORD-PROTECTED ZIP FILES',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black.withOpacity(0.5),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (_selectedFileName != null) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.file_present, color: Colors.black.withOpacity(0.7), size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedFileName!,
                                            style: TextStyle(
                                              color: Colors.black.withOpacity(0.8),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (_processingStatus.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _isFileProcessed ? Colors.black.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isFileProcessed ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isFileProcessed ? Icons.check_circle : Icons.hourglass_empty,
                                          color: _isFileProcessed ? Colors.black.withOpacity(0.8) : Colors.black.withOpacity(0.6),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _processingStatus,
                                            style: TextStyle(
                                              color: _isFileProcessed ? Colors.black.withOpacity(0.8) : Colors.black.withOpacity(0.6),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          // Premium Data Table Section
                          if (_isFileProcessed && _csvHeaders != null && _csvData != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.black.withOpacity(0.1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Premium Header
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.table_chart,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'TRANSACTION DATA',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                                          ),
                                          child: Text(
                                            '${_csvData!.length} ROWS',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Premium Filter Section
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.filter_list,
                                              size: 18,
                                              color: Colors.black,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'FILTER TRANSACTIONS',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: Colors.black,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                          decoration: InputDecoration(
                                            hintText: 'Enter Transaction ID or Publisher Transaction ID',
                                            prefixIcon: const Icon(Icons.search, size: 20),
                                            suffixIcon: _filterText.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(Icons.clear, size: 20),
                                                    onPressed: () {
                                                      setState(() {
                                                        _filterText = '';
                                                        _filterData();
                                                      });
                                                    },
                                                  )
                                                : null,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.black.withOpacity(0.2)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.black.withOpacity(0.2)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Colors.black, width: 2),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            filled: true,
                                            fillColor: Colors.black.withOpacity(0.02),
                                          ),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                          onChanged: (value) {
                                            setState(() {
                                              _filterText = value;
                                              _filterData();
                                            });
                                          },
                                        ),
                                        if (_filteredData != null && _filterText.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Found ${_filteredData!.length} matching transactions',
                                            style: TextStyle(
                                              color: Colors.black.withOpacity(0.7),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.black.withOpacity(0.1)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: InteractiveViewer(
                                        constrained: false,
                                        scaleEnabled: false,
                                        panEnabled: true,
                                        minScale: 1.0,
                                        maxScale: 1.0,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: Container(
                                            width: (_reorderedHeaders ?? _csvHeaders!).length * 150.0,
                                            child: Column(
                                              children: [
                                                // Premium Header row
                                                Container(
                                                  height: 48,
                                                  color: Colors.black,
                                                  child: Row(
                                                    children: (_reorderedHeaders ?? _csvHeaders!).asMap().entries.map((entry) {
                                                      final reorderedIndex = entry.key;
                                                      final header = entry.value;
                                                      final originalIndex = _getOriginalColumnIndex(reorderedIndex);
                                                      final isEditable = _isColumnEditable(originalIndex);
                                                      final isInput = _isInputColumn(originalIndex);
                                                      final isAutoSynced = _isAutoSyncedColumn(originalIndex);
                                                      
                                                      Color headerColor = Colors.black;
                                                      
                                                      return Container(
                                                        width: 150,
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                        decoration: BoxDecoration(
                                                          border: Border(
                                                            right: BorderSide(color: Colors.white.withOpacity(0.1)),
                                                          ),
                                                          color: headerColor,
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            if (isInput) ...[
                                                              Icon(
                                                                Icons.input,
                                                                size: 16,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 6),
                                                            ] else if (isAutoSynced) ...[
                                                              Icon(
                                                                Icons.sync,
                                                                size: 16,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 6),
                                                            ] else if (isEditable) ...[
                                                              Icon(
                                                                _isDropdownColumn(originalIndex) ? Icons.arrow_drop_down : Icons.edit,
                                                                size: 16,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 6),
                                                            ],
                                                            Expanded(
                                                              child: Text(
                                                                header,
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w700,
                                                                  fontSize: 12,
                                                                  color: Colors.white,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                                maxLines: 1,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                // Premium Data rows
                                                ..._filteredData!.asMap().entries.map((rowEntry) {
                                                  final rowIndex = _csvData!.indexOf(rowEntry.value);
                                                  final originalRow = rowEntry.value;
                                                  final reorderedRow = _getReorderedRow(originalRow);
                                                  
                                                  return Container(
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: reorderedRow.asMap().entries.map((entry) {
                                                        final reorderedCellIndex = entry.key;
                                                        final cell = entry.value;
                                                        final originalCellIndex = _getOriginalColumnIndex(reorderedCellIndex);
                                                        final cellKey = '${rowIndex}_$originalCellIndex';
                                                        final isEditable = _isColumnEditable(originalCellIndex);
                                                        final isInput = _isInputColumn(originalCellIndex);
                                                        final isAutoSynced = _isAutoSyncedColumn(originalCellIndex);
                                                        final isCurrentlyEditing = _isEditing[cellKey] ?? false;
                                                        
                                                        Color? cellBackgroundColor;
                                                        if (isInput) {
                                                          cellBackgroundColor = Colors.black.withOpacity(0.02);
                                                        } else if (isAutoSynced) {
                                                          cellBackgroundColor = Colors.black.withOpacity(0.03);
                                                        } else if (isEditable) {
                                                          cellBackgroundColor = Colors.black.withOpacity(0.04);
                                                        }
                                                        
                                                        return Container(
                                                          width: 150,
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                          decoration: BoxDecoration(
                                                            border: Border(
                                                              right: BorderSide(color: Colors.black.withOpacity(0.05)),
                                                            ),
                                                            color: cellBackgroundColor,
                                                          ),
                                                          child: isCurrentlyEditing ? 
                                                            // Premium Editing mode
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: _isDropdownColumn(originalCellIndex) ?
                                                                    // Premium Dropdown for Payout Status
                                                                    DropdownButton<String>(
                                                                      value: _dropdownValues[cellKey] ?? '1',
                                                                      isExpanded: true,
                                                                      style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
                                                                      underline: Container(),
                                                                      items: _payoutStatusOptions.entries.map((entry) {
                                                                        return DropdownMenuItem<String>(
                                                                          value: entry.key,
                                                                          child: Text('${entry.key} - ${entry.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                                                        );
                                                                      }).toList(),
                                                                      onChanged: (String? newValue) {
                                                                        if (newValue != null) {
                                                                          setState(() {
                                                                            _dropdownValues[cellKey] = newValue;
                                                                          });
                                                                        }
                                                                      },
                                                                    ) :
                                                                    // Premium Text field for other columns
                                                                    TextField(
                                                                      controller: _editControllers[cellKey],
                                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                                      decoration: const InputDecoration(
                                                                        border: InputBorder.none,
                                                                        contentPadding: EdgeInsets.zero,
                                                                        isDense: true,
                                                                      ),
                                                                      inputFormatters: _isTargetCurrencyColumn(originalCellIndex) 
                                                                          ? [UppercaseAlphabeticInputFormatter()]
                                                                          : null,
                                                                      onSubmitted: (_) => _saveEdit(rowIndex, originalCellIndex),
                                                                      autofocus: true,
                                                                    ),
                                                                ),
                                                                Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    InkWell(
                                                                      onTap: () => _saveEdit(rowIndex, originalCellIndex),
                                                                      child: Icon(Icons.check, size: 16, color: Colors.black),
                                                                    ),
                                                                    const SizedBox(width: 4),
                                                                    InkWell(
                                                                      onTap: () => _cancelEdit(rowIndex, originalCellIndex),
                                                                      child: Icon(Icons.close, size: 16, color: Colors.black),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ) :
                                                            // Premium Display mode
                                                            InkWell(
                                                              onTap: (isEditable && !isAutoSynced) ? () {
                                                                print('UI CLICK: Reordered cell $reorderedCellIndex -> Original cell $originalCellIndex');
                                                                print('  Reordered header: ${(_reorderedHeaders ?? _csvHeaders!)[reorderedCellIndex]}');
                                                                print('  Original header: ${_csvHeaders![originalCellIndex]}');
                                                                print('  Cell value: "$cell"');
                                                                _startEditing(rowIndex, originalCellIndex, cell);
                                                              } : null,
                                                              child: Container(
                                                                width: double.infinity,
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Tooltip(
                                                                        message: cell,
                                                                        child: Text(
                                                                          cell,
                                                                          style: TextStyle(
                                                                            fontSize: 12,
                                                                            color: _isNumeric(cell) ? Colors.black : Colors.black.withOpacity(0.8),
                                                                            fontWeight: _isNumeric(cell) ? FontWeight.w600 : FontWeight.w500,
                                                                          ),
                                                                          overflow: TextOverflow.ellipsis,
                                                                          maxLines: 1,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    if (isAutoSynced)
                                                                      Icon(
                                                                        Icons.sync,
                                                                        size: 14,
                                                                        color: Colors.black.withOpacity(0.6)
                                                                      )
                                                                    else if (isEditable) 
                                                                      Icon(
                                                                        _isDropdownColumn(originalCellIndex) ? Icons.arrow_drop_down : Icons.edit, 
                                                                        size: 14, 
                                                                        color: Colors.black.withOpacity(0.6)
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_csvData!.length > 15) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.black.withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: Colors.black.withOpacity(0.7),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _filterText.isNotEmpty 
                                                  ? 'Showing ${_filteredData!.length} filtered results'
                                                  : 'Showing first 15 rows of ${_csvData!.length} total rows',
                                              style: TextStyle(
                                                color: Colors.black.withOpacity(0.7),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_csvData!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.analytics_outlined,
                                          size: 16,
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _filterText.isNotEmpty
                                              ? 'Filter Results: ${_filteredData!.length} of ${_csvData!.length} rows'
                                              : 'Data Summary: ${_csvHeaders!.length} columns, ${_csvData!.length} rows',
                                          style: TextStyle(
                                            color: Colors.black.withOpacity(0.6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 32),
                          
                          // Premium Action Buttons
                          if (_editedRowIndices.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.black.withOpacity(0.1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.edit_note,
                                          size: 24,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'ACTIONS',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                          letterSpacing: 1.5,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.black.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          '${_editedRowIndices.length} EDITED',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Premium Action Buttons Row
                                  Row(
                                    children: [
                                      // Premium Email Button
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _showEmailTransactionTypeDialog,
                                              borderRadius: BorderRadius.circular(12),
                                              child: Padding(
                                                padding: const EdgeInsets.all(24),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.email,
                                                          size: 24,
                                                          color: Colors.white,
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Text(
                                                          'SEND EMAIL',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w700,
                                                            color: Colors.white,
                                                            letterSpacing: 1.0,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'Send 2 ZIP files via email to payout-qa-internal@codapayments.com',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.white.withOpacity(0.8),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Password: P@ssw0rd',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white.withOpacity(0.6),
                                                        fontStyle: FontStyle.italic,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Premium Additional API Actions Section
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.email_outlined,
                                        size: 24,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'TRIGGER REPORTS',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                        letterSpacing: 1.5,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    // Premium Wallet Report Button
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.black.withOpacity(0.1)),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _callWalletUnfinishedReportApi,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.account_balance_wallet,
                                                        size: 24,
                                                        color: Colors.black,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        'WALLET REPORT',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.black,
                                                          letterSpacing: 1.0,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Send unfinished wallet transactions report',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black.withOpacity(0.7),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Premium Bank Transfer Report Button
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.black.withOpacity(0.1)),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _callBankTransferUnfinishedReportApi,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.account_balance,
                                                        size: 24,
                                                        color: Colors.black,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        'BANK TRANSFER REPORT',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.black,
                                                          letterSpacing: 1.0,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Send unfinished bank transfer report',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black.withOpacity(0.7),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a progress step indicator
  Widget _buildProgressStep(int step, String text, bool isActive, {bool isDone = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone 
                ? Colors.green.shade100 
                : isActive 
                  ? Colors.blue.shade100 
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isDone
                ? Icon(Icons.check, size: 16, color: Colors.green.shade600)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.blue.shade600 : Colors.grey.shade600,
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDone 
                  ? Colors.green.shade700
                  : isActive 
                    ? const Color(0xFF1F2937)
                    : Colors.grey.shade600,
                fontWeight: isDone || isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (isActive && !isDone)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(left: 8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              ),
            ),
        ],
      ),
    );
  }
}
