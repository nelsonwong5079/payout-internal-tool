import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:archive/archive.dart';

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
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  Map<String, dynamic>? _apiResponse;
  
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
    
    for (int i = 0; i < _csvHeaders!.length; i++) {
      final headerLower = _csvHeaders![i].toLowerCase().trim();
      for (String editableColumn in editableColumnNames) {
        if (headerLower.contains(editableColumn)) {
          _editableColumns[editableColumn] = i;
          break;
        }
      }
    }
    
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
        if (_isDropdownColumn(columnIndex)) {
          // Save dropdown value
          _csvData![rowIndex][columnIndex] = _dropdownValues[key] ?? '';
          _dropdownValues.remove(key);
        } else {
          // Save text field value
          if (_editControllers[key] != null) {
            _csvData![rowIndex][columnIndex] = _editControllers[key]!.text;
            _editControllers[key]?.dispose();
            _editControllers.remove(key);
          }
        }
        
        _isEditing[key] = false;
        
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
    
    // If target amount was edited, copy to processed amount
    if (headerLower.contains('target') && headerLower.contains('amount')) {
      final processedAmountIndex = _editableColumns['processed amount'];
      if (processedAmountIndex != null && processedAmountIndex < _csvData![rowIndex].length) {
        _csvData![rowIndex][processedAmountIndex] = _csvData![rowIndex][columnIndex];
      }
    }
    
        // If target currency was edited, copy to processed currency (also ensure uppercase)
    if (headerLower.contains('target') && headerLower.contains('currency')) {
      final processedCurrencyIndex = _editableColumns['processed currency'];
      if (processedCurrencyIndex != null && processedCurrencyIndex < _csvData![rowIndex].length) {
        _csvData![rowIndex][processedCurrencyIndex] = _csvData![rowIndex][columnIndex].toUpperCase();
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
     
     for (int rowIndex = 0; rowIndex < _csvData!.length; rowIndex++) {
       final row = _csvData![rowIndex];
       
       // Copy target amount to processed amount
       if (targetAmountIndex != null && processedAmountIndex != null &&
           targetAmountIndex < row.length && processedAmountIndex < row.length) {
         row[processedAmountIndex] = row[targetAmountIndex];
       }
       
       // Copy target currency to processed currency (ensure uppercase)
       if (targetCurrencyIndex != null && processedCurrencyIndex != null &&
           targetCurrencyIndex < row.length && processedCurrencyIndex < row.length) {
         row[processedCurrencyIndex] = row[targetCurrencyIndex].toUpperCase();
       }
     }
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
          }
        }
      }
      
      // Initialize filtered data with all data
      _filteredData = _csvData;
      
      // Initialize editable columns
      _initializeEditableColumns();
      
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

  Future<void> _sendEmail() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _apiResponse = null;
    });

    try {
      // Firebase function URL
      const String functionUrl = 'https://us-central1-codapay-webhook.cloudfunctions.net/sendEmail';
      
      final response = await http.get(Uri.parse(functionUrl));
      
      // Parse the response
      Map<String, dynamic> responseData = {};
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        responseData = {'raw_response': response.body};
      }
      
      if (response.statusCode == 200) {
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Email sent successfully!';
          _apiResponse = responseData;
        });
      } else {
        setState(() {
          _isSuccess = false;
          _statusMessage = 'Failed to send email. Status: ${response.statusCode}';
          _apiResponse = responseData;
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Error: $e';
        _apiResponse = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                                                    onTap: (isEditable && !isAutoSynced) ? () => _startEditing(rowIndex, originalCellIndex, cell) : null,
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
                
                // Email Sending Section
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
                        'Step 2: Send Email',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This will send a test email to wkarweng98@gmail.com',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Send Email',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Status Messages
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSuccess ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle : Icons.error,
                          color: _isSuccess ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // API Response Display
                if (_apiResponse != null) ...[
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
                            const Icon(Icons.code, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'API Response:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ').convert(_apiResponse),
                            style: const TextStyle(
                              color: Colors.green,
                              fontFamily: 'monospace',
                              fontSize: 12,
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
        ),
      ),
    );
  }
}
