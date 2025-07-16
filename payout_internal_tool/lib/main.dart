import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:archive/archive.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Payout Internal Tool'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
              if (_isFileProcessed && _fileContent != null) ...[
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
                          const Icon(Icons.description, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'File Content:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _fileContent!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
            ),
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
    );
  }
}
