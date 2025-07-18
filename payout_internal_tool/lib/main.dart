import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'dart:math' as math;

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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Sender',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EmailSenderPage(),
    );
  }
}

class EmailSenderPage extends StatefulWidget {
  const EmailSenderPage({super.key});

  @override
  State<EmailSenderPage> createState() => _EmailSenderPageState();
}

class _EmailSenderPageState extends State<EmailSenderPage> {
  
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

  // File upload handler
  void _handleFileUpload() {
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
  
  // Show transaction type selection dialog
  void _showTransactionTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Transaction Type'),
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
                    _showFileNameDialog();
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
                    _showFileNameDialog();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Show file name input dialog
  void _showFileNameDialog() {
    final TextEditingController fileNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter ZIP File Name'),
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
                'Final file names will be:\n'
                '• ${fileNameController.text.isEmpty ? "filename" : fileNameController.text}$_transactionType.csv\n'
                '• approved_${fileNameController.text.isEmpty ? "filename" : fileNameController.text}$_transactionType.csv',
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
                  _generateAndDownloadFiles(fileNameController.text.trim());
                }
              },
              child: const Text('Generate Files'),
            ),
          ],
        );
      },
    );
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
  
  // Send email with generated ZIP files
  Future<void> _sendEmailWithFiles(String baseName) async {
    if (_editedRowIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No edited rows to send via email')),
      );
      return;
    }
    
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Generating and sending ZIP files via email...'),
            ],
          ),
          duration: Duration(seconds: 15),
        ),
      );

      // Generate CSV content with user's selected payout status
      final originalContent = _generateEditedCsvContent();
      
      print('=== EMAIL PAYLOAD DEBUG ===');
      print('CSV content being sent to email API:');
      print('--- CSV START ---');
      print(originalContent);
      print('--- CSV END ---');
      print('Email API will generate and send:');
      print('1. Email with approved_${baseName}${_transactionType}.zip - All payout status = APPROVED');
      print('2. Email with ${baseName}${_transactionType}.zip - User\'s selected payout status');
      print('To: wkarweng98@gmail.com');
      print('==============================');
      
             // Call backend API to send email with ZIP files
       final response = await http.post(
         Uri.parse('https://sendemail-amxcplfi6q-uc.a.run.app'),
         headers: {'Content-Type': 'application/json'},
         body: json.encode({
           'originalCsv': originalContent,
           'fileName': baseName,
           'transactionType': _transactionType,
         }),
       );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Email sent successfully!\n'
                '• ${responseData['files']['approved']} (All status = APPROVED)\n'
                '• ${responseData['files']['original']} (Your selected status)\n'
                'Sent to: ${responseData['recipient']}\n'
                'Password: P@ssw0rd'
              ),
              duration: const Duration(seconds: 8),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Backend returned error: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending email: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Generate and download password-protected ZIP files via backend
  Future<void> _generateAndDownloadFiles(String baseName) async {
    if (_editedRowIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No edited rows to export')),
      );
      return;
    }
    
    try {
              // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Generating password-protected ZIP files...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );

      // Generate CSV content with user's selected payout status
      final originalContent = _generateEditedCsvContent();
      
      print('=== BACKEND PAYLOAD DEBUG ===');
      print('CSV content being sent to backend (with user\'s selected payout status):');
      print('--- CSV START ---');
      print(originalContent);
      print('--- CSV END ---');
      print('Backend will generate:');
      print('1. approved_${baseName}${_transactionType}.zip - All payout status = APPROVED');
      print('2. ${baseName}${_transactionType}.zip - User\'s selected payout status');
      print('==============================');
      
      // Call backend API to create ZIP files
      final response = await http.post(
        Uri.parse('https://generatezipfiles-amxcplfi6q-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'originalCsv': originalContent,
          'fileName': baseName,
          'transactionType': _transactionType,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final files = responseData['files'];
          
          print('=== DOWNLOAD DEBUG ===');
          print('File 1 (Approved): ${files['approved']['name']} - All payout status = APPROVED');
          print('File 2 (Original): ${files['original']['name']} - User\'s selected payout status');
          print('Number of edited rows exported: ${_editedRowIndices.length}');
          print('Edited row indices: $_editedRowIndices');
          print('======================');
          
          // Download both ZIP files (approved first, then original)
          _downloadZipFile(files['approved']['content'], files['approved']['name']);
          
          // Delay the second download slightly
          Future.delayed(const Duration(milliseconds: 500), () {
            _downloadZipFile(files['original']['content'], files['original']['name']);
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Generated password-protected ZIP files:\n'
                '• ${files['approved']['name']} (${_editedRowIndices.length} edited rows - ALL payout status = APPROVED)\n'
                '• ${files['original']['name']} (${_editedRowIndices.length} edited rows - YOUR selected payout status)\n'
                'Password: P@ssw0rd'
              ),
              duration: const Duration(seconds: 8),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Backend returned error: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating ZIP files: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }



  @override
  void dispose() {
    // Clean up all text editing controllers
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    _dropdownValues.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Payout Internal Tool'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.upload_file,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 32),
                const Text(
                  'File Upload & Processing',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload CSV or ZIP files for processing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                
                // File Upload Section
                Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Step 1: File Selection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _handleFileUpload,
                          icon: const Icon(Icons.upload),
                          label: const Text('Choose File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedFileName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.file_present, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: $_selectedFileName',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_processingStatus.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isFileProcessed ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isFileProcessed ? Colors.green : Colors.orange,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isFileProcessed ? Icons.check_circle : Icons.hourglass_empty,
                                color: _isFileProcessed ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _processingStatus,
                                  style: TextStyle(
                                    color: _isFileProcessed ? Colors.green.shade800 : Colors.orange.shade800,
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
                
                // File Content Display
                if (_isFileProcessed && _csvHeaders != null && _csvData != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.table_chart, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'CSV Data Table:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Filter Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.filter_list, size: 16, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Filter by Transaction ID:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: Colors.blue),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 13),
                                onChanged: (value) {
                                  setState(() {
                                    _filterText = value;
                                    _filterData();
                                  });
                                },
                              ),
                              if (_filteredData != null && _filterText.isNotEmpty) ...[
                                const SizedBox(height: 8),
            Text(
                                  'Found ${_filteredData!.length} matching transactions',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
          ],
        ),
      ),
                        
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.4,
                          ),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 4,
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
                                      // Header row
                                      Container(
                                        height: 40,
                                        color: Colors.blue.shade600,
                                        child: Row(
                                          children: (_reorderedHeaders ?? _csvHeaders!).asMap().entries.map((entry) {
                                            final reorderedIndex = entry.key;
                                            final header = entry.value;
                                            final originalIndex = _getOriginalColumnIndex(reorderedIndex);
                                            final isEditable = _isColumnEditable(originalIndex);
                                            final isInput = _isInputColumn(originalIndex);
                                            final isAutoSynced = _isAutoSyncedColumn(originalIndex);
                                            
                                            Color headerColor;
                                            if (isInput) {
                                              headerColor = Colors.green.shade600; // Green for input columns
                                            } else if (isAutoSynced) {
                                              headerColor = Colors.orange.shade600; // Orange for auto-synced columns
                                            } else if (isEditable) {
                                              headerColor = Colors.blue.shade700; // Dark blue for editable
                                            } else {
                                              headerColor = Colors.blue.shade600; // Regular blue for read-only
                                            }
                                            
                                            return Container(
                                              width: 150,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                color: headerColor,
                                              ),
                                              child: Row(
                                                children: [
                                                  if (isInput) ...[
                                                    Icon(
                                                      Icons.input,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ] else if (isAutoSynced) ...[
                                                    Icon(
                                                      Icons.sync,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ] else if (isEditable) ...[
                                                    Icon(
                                                      _isDropdownColumn(originalIndex) ? Icons.arrow_drop_down : Icons.edit,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      header,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: Colors.white,
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
                                      // Data rows
                                      ..._filteredData!.asMap().entries.map((rowEntry) {
                                        final rowIndex = _csvData!.indexOf(rowEntry.value);
                                        final originalRow = rowEntry.value;
                                        final reorderedRow = _getReorderedRow(originalRow);
                                        
                                        return Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Colors.grey.shade200),
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
                                                cellBackgroundColor = Colors.green.shade50; // Light green for input columns
                                              } else if (isAutoSynced) {
                                                cellBackgroundColor = Colors.orange.shade50; // Light orange for auto-synced columns
                                              } else if (isEditable) {
                                                cellBackgroundColor = Colors.blue.shade50; // Light blue for editable columns
                                              }
                                              
                                              return Container(
                                                width: 150,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right: BorderSide(color: Colors.grey.shade200),
                                                  ),
                                                  color: cellBackgroundColor,
                                                ),
                                                child: isCurrentlyEditing ? 
                                                  // Editing mode
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: _isDropdownColumn(originalCellIndex) ?
                                                          // Dropdown for Payout Status
                                                          DropdownButton<String>(
                                                            value: _dropdownValues[cellKey] ?? '1',
                                                            isExpanded: true,
                                                            style: const TextStyle(fontSize: 11, color: Colors.black),
                                                            underline: Container(),
                                                            items: _payoutStatusOptions.entries.map((entry) {
                                                              return DropdownMenuItem<String>(
                                                                value: entry.key,
                                                                child: Text('${entry.key} - ${entry.value}', style: const TextStyle(fontSize: 11)),
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
                                                          // Text field for other columns
                                                          TextField(
                                                            controller: _editControllers[cellKey],
                                                            style: const TextStyle(fontSize: 11),
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
                                                            child: Icon(Icons.check, size: 14, color: Colors.green),
                                                          ),
                                                          const SizedBox(width: 2),
                                                          InkWell(
                                                            onTap: () => _cancelEdit(rowIndex, originalCellIndex),
                                                            child: Icon(Icons.close, size: 14, color: Colors.red),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ) :
                                                  // Display mode
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
                                                                  fontSize: 11,
                                                                  color: _isNumeric(cell) ? Colors.green.shade700 : Colors.black87,
                                                                  fontWeight: _isNumeric(cell) ? FontWeight.w500 : FontWeight.normal,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                                maxLines: 1,
                                                              ),
                                                            ),
                                                          ),
                                                          if (isAutoSynced)
                                                            Icon(
                                                              Icons.sync,
                                                              size: 12,
                                                              color: Colors.orange.shade600
                                                            )
                                                          else if (isEditable) 
                                                            Icon(
                                                              _isDropdownColumn(originalCellIndex) ? Icons.arrow_drop_down : Icons.edit, 
                                                              size: 12, 
                                                              color: Colors.blue.shade600
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
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _filterText.isNotEmpty 
                                        ? 'Showing ${_filteredData!.length} filtered results'
                                        : 'Showing first 15 rows of ${_csvData!.length} total rows',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_csvData!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
            Text(
                                _filterText.isNotEmpty
                                    ? 'Filter Results: ${_filteredData!.length} of ${_csvData!.length} rows'
                                    : 'Data Summary: ${_csvHeaders!.length} columns, ${_csvData!.length} rows',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
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
                
                // Email Section
                if (_editedRowIndices.isNotEmpty) ...[
                  Container(
                    width: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Step 2: Send Email',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Send ${_editedRowIndices.length} modified transaction(s) via email to wkarweng98@gmail.com',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'This will send 2 separate emails with:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              SizedBox(height: 4),
                              Text('• Email 1: ZIP file with ALL payout status = APPROVED', style: TextStyle(fontSize: 11)),
                              Text('• Email 2: ZIP file with YOUR selected payout status', style: TextStyle(fontSize: 11)),
                              Text('• Password: P@ssw0rd for both files', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _showEmailTransactionTypeDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Send Email',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                
                // Export Section
                if (_editedRowIndices.isNotEmpty) ...[
                  Container(
                    width: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Step 3: Export Modified Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Export ${_editedRowIndices.length} modified transaction(s) to CSV files',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'This will generate:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              const Text('• Original CSV with your edits', style: TextStyle(fontSize: 11)),
                              const Text('• Approved CSV (all status = SUCCESS)', style: TextStyle(fontSize: 11)),
                              const Text('• Files contain only modified rows', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _showTransactionTypeDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Export CSV Files',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }
}
