import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class SandboxMonitoringScreen extends StatefulWidget {
  const SandboxMonitoringScreen({super.key});

  @override
  State<SandboxMonitoringScreen> createState() => _SandboxMonitoringScreenState();
}

class _SandboxMonitoringScreenState extends State<SandboxMonitoringScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _refreshController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _refreshAnimation;

  // Data state
  Map<String, dynamic>? _monitoringData;
  Map<String, dynamic>? _monitoringDataV2;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  
  // Historical data (last 7 days) - Stored in memory only (not persisted)
  // This data is lost when the app is refreshed or closed
  // For persistent storage, we would need to implement local storage (SharedPreferences) or database
  List<Map<String, dynamic>> _historicalData = [];
  
  // Auto-refresh timer


  // Iframe view registration - for embedding sandbox content
  bool _isIframeRegistered = false;
  bool _isIframeRegisteredV2 = false;
  String? _currentLcyViewFactory;
  String? _currentUsdViewFactory;
  String? _currentLcyViewFactoryV2;
  String? _currentUsdViewFactoryV2;
  String? _currentLcyViewFactoryPaytype0;
  String? _currentUsdViewFactoryPaytype0;
  String? _currentLcyViewFactoryV2Paytype0;
  String? _currentUsdViewFactoryV2Paytype0;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _refreshAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _refreshController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    
    // Load initial data
    _loadMonitoringData();
    
    // Load initial data only - scheduled checks are handled by backend
        _loadMonitoringData();
      }

    // Get next scheduled backend check time
  String _getNextScheduledCheck() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8)); // Convert to GMT+8
    final currentHour = now.hour;
    
    if (currentHour < 9) {
      return '9:00 AM GMT+8';
    } else if (currentHour < 13) {
      return '1:00 PM GMT+8';
    } else {
      // If past 1 PM, next check is tomorrow at 9 AM
      return '9:00 AM GMT+8 (Tomorrow)';
    }
  }

  // Trigger mock fail scenario for testing
  Future<void> _triggerMockFail() async {
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-codapay-webhook.cloudfunctions.net/triggerMockFail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Show success snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.orange.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                                                  child: Text(
                            'Mock fail triggered successfully! Check email: nelson.wong@codapayments.com',
                          style: TextStyle(
                            color: Colors.orange.shade700,
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
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      } else {
        throw Exception('Failed to trigger mock fail: ${response.body}');
      }
    } catch (error) {
      // Show error snackbar
      if (mounted) {
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
                      'Error triggering mock fail: $error',
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
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _refreshController.dispose();
    super.dispose();
  }



  // Load monitoring data from Firebase function
  Future<void> _loadMonitoringData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load both v1 and v2 data in parallel
      final responses = await Future.wait([
        http.post(
        Uri.parse('https://checksandboxstatus-amxcplfi6q-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
        ),
        http.post(
          Uri.parse('https://us-central1-codapay-webhook.cloudfunctions.net/checkSandboxStatusV2'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({}),
        ),
      ]);
      
      bool hasError = false;
      String errorMessage = '';
      Map<String, dynamic>? v1Data;
      Map<String, dynamic>? v2Data;
      
      // Process v1 response
      if (responses[0].statusCode == 200) {
        final data = json.decode(responses[0].body);
        if (data['success'] == true) {
          v1Data = data['data'];
          
          // Debug logging
          print('V1 Data received: ${v1Data?.keys.toList()}');
          
          // Handle both old and new data structures
          if (v1Data != null && v1Data.containsKey('paytype237')) {
            // New structure
            print('Using new V1 data structure');
            setState(() {
              _monitoringData = v1Data;
            });
          } else if (v1Data != null && v1Data.containsKey('lcy')) {
            // Old structure - convert to new structure
            print('Converting old V1 data structure to new structure');
            final convertedData = {
              'timestamp': v1Data['timestamp'],
              'paytype237': {
                'lcy': v1Data['lcy'],
                'usd': v1Data['usd'],
              },
              'paytype0': {
                'lcy': v1Data['lcy'], // Use same data for now
                'usd': v1Data['usd'], // Use same data for now
              },
            };
            setState(() {
              _monitoringData = convertedData;
            });
            v1Data = convertedData;
          } else {
            print('V1 Data structure not recognized: ${v1Data?.keys.toList()}');
            // Create empty structure to prevent crashes
            final emptyData = {
              'timestamp': DateTime.now().toIso8601String(),
              'paytype237': {
                'lcy': {'status': 'UNKNOWN', 'responseTime': 0},
                'usd': {'status': 'UNKNOWN', 'responseTime': 0},
              },
              'paytype0': {
                'lcy': {'status': 'UNKNOWN', 'responseTime': 0},
                'usd': {'status': 'UNKNOWN', 'responseTime': 0},
              },
            };
            setState(() {
              _monitoringData = emptyData;
            });
            v1Data = emptyData;
          }
          
          // Add to historical data
          if (_monitoringData != null) {
            _addToHistoricalData(_monitoringData!);
          }
          
          // Register iframe views after data is loaded
          _registerIframeViews();
        } else {
          hasError = true;
          errorMessage = data['error'] ?? 'Unknown error occurred';
        }
      } else {
        hasError = true;
        errorMessage = 'HTTP ${responses[0].statusCode}: ${responses[0].reasonPhrase}';
      }
      
      // Process v2 response
      if (responses[1].statusCode == 200) {
        final data = json.decode(responses[1].body);
        if (data['success'] == true) {
          v2Data = data['data'];
          
          // Debug logging
          print('V2 Data received: ${v2Data?.keys.toList()}');
          
          // Handle both old and new data structures
          if (v2Data != null && v2Data.containsKey('paytype237')) {
            // New structure
            print('Using new V2 data structure');
            setState(() {
              _monitoringDataV2 = v2Data;
            });
          } else if (v2Data != null && v2Data.containsKey('lcy')) {
            // Old structure - convert to new structure
            print('Converting old V2 data structure to new structure');
            final convertedData = {
              'timestamp': v2Data['timestamp'],
              'paytype237': {
                'lcy': v2Data['lcy'],
                'usd': v2Data['usd'],
              },
              'paytype0': {
                'lcy': v2Data['lcy'], // Use same data for now
                'usd': v2Data['usd'], // Use same data for now
              },
            };
            setState(() {
              _monitoringDataV2 = convertedData;
            });
            v2Data = convertedData;
          } else {
            print('V2 Data structure not recognized: ${v2Data?.keys.toList()}');
            // Create empty structure to prevent crashes
            final emptyData = {
              'timestamp': DateTime.now().toIso8601String(),
              'paytype237': {
                'lcy': {'status': 'UNKNOWN', 'responseTime': 0},
                'usd': {'status': 'UNKNOWN', 'responseTime': 0},
              },
              'paytype0': {
                'lcy': {'status': 'UNKNOWN', 'responseTime': 0},
                'usd': {'status': 'UNKNOWN', 'responseTime': 0},
              },
            };
            setState(() {
              _monitoringDataV2 = emptyData;
            });
            v2Data = emptyData;
          }
          
          // Register v2 iframe views after data is loaded
          _registerIframeViewsV2();
        } else {
          hasError = true;
          errorMessage += ' | V2: ${data['error'] ?? 'Unknown error occurred'}';
        }
      } else {
        hasError = true;
        errorMessage += ' | V2: HTTP ${responses[1].statusCode}: ${responses[1].reasonPhrase}';
      }
      
      setState(() {
        _isLoading = false;
        if (hasError) {
          _errorMessage = errorMessage;
        }
      });

      // Check for failures and trigger email notification
      if (v1Data != null || v2Data != null) {
        _checkForFailuresAndNotify(v1Data, v2Data);
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Network error: ${error.toString()}';
        _isLoading = false;
      });
    }
  }

  // Check for failures and trigger email notification
  Future<void> _checkForFailuresAndNotify(Map<String, dynamic>? v1Data, Map<String, dynamic>? v2Data) async {
    try {
      List<Map<String, dynamic>> failedChecks = [];
      
      // Check v1 data for failures
      if (v1Data != null) {
        // Check Paytype237 failures
        final paytype237LcyStatus = v1Data['paytype237']?['lcy']?['status'];
        final paytype237UsdStatus = v1Data['paytype237']?['usd']?['status'];
        
        if (paytype237LcyStatus == 'DOWN') {
          failedChecks.add({
            'version': 'v1',
            'paytype': '237',
            'currency': 'LCY (MYR)',
            'status': 'DOWN',
            'errorMessage': v1Data['paytype237']?['lcy']?['errorMessage'] ?? 'Unknown error',
          });
        }
        
        if (paytype237UsdStatus == 'DOWN') {
          failedChecks.add({
            'version': 'v1',
            'paytype': '237',
            'currency': 'USD',
            'status': 'DOWN',
            'errorMessage': v1Data['paytype237']?['usd']?['errorMessage'] ?? 'Unknown error',
          });
        }

        // Check Paytype0 failures
        final paytype0LcyStatus = v1Data['paytype0']?['lcy']?['status'];
        final paytype0UsdStatus = v1Data['paytype0']?['usd']?['status'];
        
        if (paytype0LcyStatus == 'DOWN') {
          failedChecks.add({
            'version': 'v1',
            'paytype': '0',
            'currency': 'LCY (MYR)',
            'status': 'DOWN',
            'errorMessage': v1Data['paytype0']?['lcy']?['errorMessage'] ?? 'Unknown error',
          });
        }
        
        if (paytype0UsdStatus == 'DOWN') {
          failedChecks.add({
            'version': 'v1',
            'paytype': '0',
            'currency': 'USD',
            'status': 'DOWN',
            'errorMessage': v1Data['paytype0']?['usd']?['errorMessage'] ?? 'Unknown error',
          });
        }
      }
      
      // Check v2 data for failures
      if (v2Data != null) {
        // Check Paytype237 failures
        final paytype237LcyStatusV2 = v2Data['paytype237']?['lcy']?['status'];
        final paytype237UsdStatusV2 = v2Data['paytype237']?['usd']?['status'];
        
        if (paytype237LcyStatusV2 == 'DOWN') {
          failedChecks.add({
            'version': 'v2',
            'paytype': '237',
            'currency': 'LCY (MYR)',
            'status': 'DOWN',
            'errorMessage': v2Data['paytype237']?['lcy']?['errorMessage'] ?? 'Unknown error',
          });
        }
        
        if (paytype237UsdStatusV2 == 'DOWN') {
          failedChecks.add({
            'version': 'v2',
            'paytype': '237',
            'currency': 'USD',
            'status': 'DOWN',
            'errorMessage': v2Data['paytype237']?['usd']?['errorMessage'] ?? 'Unknown error',
          });
        }

        // Check Paytype0 failures
        final paytype0LcyStatusV2 = v2Data['paytype0']?['lcy']?['status'];
        final paytype0UsdStatusV2 = v2Data['paytype0']?['usd']?['status'];
        
        if (paytype0LcyStatusV2 == 'DOWN') {
          failedChecks.add({
            'version': 'v2',
            'paytype': '0',
            'currency': 'LCY (MYR)',
            'status': 'DOWN',
            'errorMessage': v2Data['paytype0']?['lcy']?['errorMessage'] ?? 'Unknown error',
          });
        }
        
        if (paytype0UsdStatusV2 == 'DOWN') {
          failedChecks.add({
            'version': 'v2',
            'paytype': '0',
            'currency': 'USD',
            'status': 'DOWN',
            'errorMessage': v2Data['paytype0']?['usd']?['errorMessage'] ?? 'Unknown error',
          });
        }
      }
      
      // If there are failures, trigger email notification
      if (failedChecks.isNotEmpty) {
        await _triggerFailureEmail(failedChecks);
      }
    } catch (error) {
      // Log error but don't show to user to avoid confusion
      print('Error checking for failures: $error');
    }
  }

  // Trigger failure email notification
  Future<void> _triggerFailureEmail(List<Map<String, dynamic>> failedChecks) async {
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-codapay-webhook.cloudfunctions.net/triggerFailureEmail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'failedChecks': failedChecks}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Show success notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Failure detected! Alert email sent to: nelson.wong@codapayments.com, wkarweng@icloud.com',
                          style: TextStyle(
                            color: Colors.orange.shade700,
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
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      }
    } catch (error) {
      // Log error but don't show to user to avoid confusion
      print('Error triggering failure email: $error');
    }
  }

  // Manual refresh with animation and fresh transaction IDs
  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    _refreshController.forward();
    
    // Reset iframe registration to force fresh transaction IDs
    setState(() {
      _isIframeRegistered = false;
      _isIframeRegisteredV2 = false;
    });
    
    await _loadMonitoringData();
    
    _refreshController.reverse();
    
    setState(() {
      _isRefreshing = false;
    });
  }

  // Load v2.0 monitoring data from Firebase Functions
  Future<void> _loadMonitoringDataV2() async {
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-codapay-webhook.cloudfunctions.net/checkSandboxStatusV2'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _monitoringDataV2 = data['data'];
          });
          
          // Register v2 iframe views after data is loaded
          _registerIframeViewsV2();
        }
      }
    } catch (error) {
      // Handle v2 errors silently to not affect v1 functionality
      print('V2.0 API Error: ${error.toString()}');
    }
  }

  // Register iframe views for embedding sandbox content with security restrictions
  void _registerIframeViews() {
    if (_isIframeRegistered || _monitoringData == null) return;
    
    // Get transaction IDs for both paytypes
    final paytype237LcyTxnId = _monitoringData!['paytype237']?['lcy']?['txnId'];
    final paytype237UsdTxnId = _monitoringData!['paytype237']?['usd']?['txnId'];
    final paytype0LcyTxnId = _monitoringData!['paytype0']?['lcy']?['txnId'];
    final paytype0UsdTxnId = _monitoringData!['paytype0']?['usd']?['txnId'];
    
    // Generate unique view factory names with timestamp to ensure fresh content
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final paytype237LcyViewFactoryName = 'lcy-sandbox-iframe-paytype237-$timestamp';
    final paytype237UsdViewFactoryName = 'usd-sandbox-iframe-paytype237-$timestamp';
    final paytype0LcyViewFactoryName = 'lcy-sandbox-iframe-paytype0-$timestamp';
    final paytype0UsdViewFactoryName = 'usd-sandbox-iframe-paytype0-$timestamp';
    
    // Register Paytype 237 iframes
    if (paytype237LcyTxnId != null) {
      final lcyUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype237LcyTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype237LcyViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = lcyUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    if (paytype237UsdTxnId != null) {
      final usdUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype237UsdTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype237UsdViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = usdUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    // Register Paytype 0 iframes
    if (paytype0LcyTxnId != null) {
      final lcyUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype0LcyTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype0LcyViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = lcyUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    if (paytype0UsdTxnId != null) {
      final usdUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype0UsdTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype0UsdViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = usdUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    setState(() {
      _isIframeRegistered = true;
      // Store the current view factory names for use in the UI
      _currentLcyViewFactory = paytype237LcyViewFactoryName;
      _currentUsdViewFactory = paytype237UsdViewFactoryName;
      // Store Paytype 0 view factory names
      _currentLcyViewFactoryPaytype0 = paytype0LcyViewFactoryName;
      _currentUsdViewFactoryPaytype0 = paytype0UsdViewFactoryName;
    });
  }

  // Register v2.0 iframe views for embedding sandbox content with security restrictions
  void _registerIframeViewsV2() {
    if (_isIframeRegisteredV2 || _monitoringDataV2 == null) return;
    
    // Get transaction IDs for both paytypes
    final paytype237LcyTxnId = _monitoringDataV2!['paytype237']?['lcy']?['txnId'];
    final paytype237UsdTxnId = _monitoringDataV2!['paytype237']?['usd']?['txnId'];
    final paytype0LcyTxnId = _monitoringDataV2!['paytype0']?['lcy']?['txnId'];
    final paytype0UsdTxnId = _monitoringDataV2!['paytype0']?['usd']?['txnId'];
    
    // Generate unique view factory names with timestamp to ensure fresh content
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final paytype237LcyViewFactoryName = 'lcy-sandbox-iframe-v2-paytype237-$timestamp';
    final paytype237UsdViewFactoryName = 'usd-sandbox-iframe-v2-paytype237-$timestamp';
    final paytype0LcyViewFactoryName = 'lcy-sandbox-iframe-v2-paytype0-$timestamp';
    final paytype0UsdViewFactoryName = 'usd-sandbox-iframe-v2-paytype0-$timestamp';
    
    // Register Paytype 237 iframes
    if (paytype237LcyTxnId != null) {
      final lcyUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype237LcyTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype237LcyViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = lcyUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    if (paytype237UsdTxnId != null) {
      final usdUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype237UsdTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype237UsdViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = usdUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    // Register Paytype 0 iframes
    if (paytype0LcyTxnId != null) {
      final lcyUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype0LcyTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype0LcyViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = lcyUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    if (paytype0UsdTxnId != null) {
      final usdUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$paytype0UsdTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        paytype0UsdViewFactoryName,
        (int viewId) => html.IFrameElement()
          ..src = usdUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Security restrictions to prevent popups and unwanted behaviors
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms')
          ..setAttribute('allow', 'payment') // Allow payment APIs if needed
          ..setAttribute('referrerpolicy', 'no-referrer') // Don't send referrer info
          ..setAttribute('loading', 'lazy') // Lazy load for performance
          // Additional security attributes
          ..setAttribute('allowfullscreen', 'false')
          ..setAttribute('allowpaymentrequest', 'false'),
      );
    }
    
    setState(() {
      _isIframeRegisteredV2 = true;
      // Store the current view factory names for use in the UI
      _currentLcyViewFactoryV2 = paytype237LcyViewFactoryName;
      _currentUsdViewFactoryV2 = paytype237UsdViewFactoryName;
      // Store Paytype 0 view factory names for V2
      _currentLcyViewFactoryV2Paytype0 = paytype0LcyViewFactoryName;
      _currentUsdViewFactoryV2Paytype0 = paytype0UsdViewFactoryName;
    });
  }

  // Add current data to historical records
  // Note: This data is stored in memory only and will be lost when the app is refreshed
  // For persistent storage across app sessions, we would need to implement:
  // 1. SharedPreferences for simple key-value storage
  // 2. SQLite database for more complex data
  // 3. Cloud Firestore for cloud-based storage
  void _addToHistoricalData(Map<String, dynamic> data) {
    final newRecord = {
      'timestamp': data['timestamp'],
      'paytype237': data['paytype237'],
      'paytype0': data['paytype0'],
    };
    
    setState(() {
      _historicalData.insert(0, newRecord);
      
      // Keep only last 7 days of data
      if (_historicalData.length > 7) {
        _historicalData = _historicalData.take(7).toList();
      }
    });
  }

  // Format timestamp for display in GMT+8
  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      // Convert to GMT+8 timezone
      final gmt8DateTime = dateTime.toUtc().add(const Duration(hours: 8));
      return '${gmt8DateTime.day}/${gmt8DateTime.month}/${gmt8DateTime.year} ${gmt8DateTime.hour}:${gmt8DateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  // Build API status indicators
  Widget _buildApiStatusIndicators() {
    // Determine v1 and v2 status
    bool v1Up = false;
    bool v2Up = false;
    
    if (_monitoringData != null) {
      final paytype237LcyStatus = _monitoringData!['paytype237']?['lcy']?['status'] ?? 'UNKNOWN';
      final paytype237UsdStatus = _monitoringData!['paytype237']?['usd']?['status'] ?? 'UNKNOWN';
      final paytype0LcyStatus = _monitoringData!['paytype0']?['lcy']?['status'] ?? 'UNKNOWN';
      final paytype0UsdStatus = _monitoringData!['paytype0']?['usd']?['status'] ?? 'UNKNOWN';
      v1Up = paytype237LcyStatus == 'UP' && paytype237UsdStatus == 'UP' &&
              paytype0LcyStatus == 'UP' && paytype0UsdStatus == 'UP';
    }
    
    if (_monitoringDataV2 != null) {
      final paytype237LcyStatusV2 = _monitoringDataV2!['paytype237']?['lcy']?['status'] ?? 'UNKNOWN';
      final paytype237UsdStatusV2 = _monitoringDataV2!['paytype237']?['usd']?['status'] ?? 'UNKNOWN';
      final paytype0LcyStatusV2 = _monitoringDataV2!['paytype0']?['lcy']?['status'] ?? 'UNKNOWN';
      final paytype0UsdStatusV2 = _monitoringDataV2!['paytype0']?['usd']?['status'] ?? 'UNKNOWN';
      v2Up = paytype237LcyStatusV2 == 'UP' && paytype237UsdStatusV2 == 'UP' &&
             paytype0LcyStatusV2 == 'UP' && paytype0UsdStatusV2 == 'UP';
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF475569).withOpacity(0.3),
          width: 1,
        ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.api,
                  size: 20,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'API STATUS OVERVIEW',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // V1 API Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: v1Up 
                          ? [
                              const Color(0xFF10B981).withOpacity(0.2),
                              const Color(0xFF059669).withOpacity(0.2),
                            ]
                          : [
                              const Color(0xFFDC2626).withOpacity(0.2),
                              const Color(0xFFB91C1C).withOpacity(0.2),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: v1Up 
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : const Color(0xFFDC2626).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        v1Up ? Icons.check_circle : Icons.error,
                        size: 20,
                        color: v1Up 
                            ? const Color(0xFF10B981)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'v1.0 API',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              v1Up ? 'All Systems Operational' : 'Service Disrupted',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: v1Up 
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : const Color(0xFFDC2626).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v1Up ? 'UP' : 'DOWN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: v1Up 
                                ? const Color(0xFF10B981)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // V2 API Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: v2Up 
                          ? [
                              const Color(0xFF8B5CF6).withOpacity(0.2),
                              const Color(0xFF7C3AED).withOpacity(0.2),
                            ]
                          : [
                              const Color(0xFFDC2626).withOpacity(0.2),
                              const Color(0xFFB91C1C).withOpacity(0.2),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: v2Up 
                          ? const Color(0xFF8B5CF6).withOpacity(0.3)
                          : const Color(0xFFDC2626).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        v2Up ? Icons.check_circle : Icons.error,
                        size: 20,
                        color: v2Up 
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'v2.0 API',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              v2Up ? 'All Systems Operational' : 'Service Disrupted',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: v2Up 
                              ? const Color(0xFF8B5CF6).withOpacity(0.2)
                              : const Color(0xFFDC2626).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v2Up ? 'UP' : 'DOWN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: v2Up 
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build detailed API status breakdown
  Widget _buildDetailedApiStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF475569).withOpacity(0.3),
          width: 1,
        ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  size: 20,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'DETAILED API STATUS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // V1 Detailed Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'v1.0 API Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_monitoringData != null) ...[
                      // Paytype 237
                      Text(
                        'Paytype 237:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', _monitoringData!['paytype237']?['lcy']?['status'] ?? 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', _monitoringData!['paytype237']?['usd']?['status'] ?? 'UNKNOWN', '840'),
                      const SizedBox(height: 8),
                      // Paytype 0
                      Text(
                        'Paytype 0:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', _monitoringData!['paytype0']?['lcy']?['status'] ?? 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', _monitoringData!['paytype0']?['usd']?['status'] ?? 'UNKNOWN', '840'),
                    ] else ...[
                      Text(
                        'Paytype 237:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', 'UNKNOWN', '840'),
                      const SizedBox(height: 8),
                      Text(
                        'Paytype 0:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', 'UNKNOWN', '840'),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // V2 Detailed Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'v2.0 API Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_monitoringDataV2 != null) ...[
                      // Paytype 237
                      Text(
                        'Paytype 237:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', _monitoringDataV2!['paytype237']?['lcy']?['status'] ?? 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', _monitoringDataV2!['paytype237']?['usd']?['status'] ?? 'UNKNOWN', '840'),
                      const SizedBox(height: 8),
                      // Paytype 0
                      Text(
                        'Paytype 0:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', _monitoringDataV2!['paytype0']?['lcy']?['status'] ?? 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', _monitoringDataV2!['paytype0']?['usd']?['status'] ?? 'UNKNOWN', '840'),
                    ] else ...[
                      Text(
                        'Paytype 237:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', 'UNKNOWN', '840'),
                      const SizedBox(height: 8),
                      Text(
                        'Paytype 0:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencyStatusItem('LCY', 'UNKNOWN', '458'),
                      const SizedBox(height: 2),
                      _buildCurrencyStatusItem('USD', 'UNKNOWN', '840'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build individual currency status item
  Widget _buildCurrencyStatusItem(String currency, String status, String code) {
    final isUp = status == 'UP';
    return Row(
      children: [
        Icon(
          isUp ? Icons.check_circle : Icons.error,
          size: 16,
          color: isUp 
              ? const Color(0xFF10B981)
              : const Color(0xFFDC2626),
        ),
        const SizedBox(width: 8),
        Text(
          '$currency ($code)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isUp 
                ? const Color(0xFF10B981).withOpacity(0.2)
                : const Color(0xFFDC2626).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isUp 
                  ? const Color(0xFF10B981)
                  : const Color(0xFFDC2626),
            ),
          ),
        ),
      ],
    );
  }

  // Build metrics grid only (without header)
  Widget _buildMetricsGrid() {
    if (_monitoringData == null) {
      return Container(); // Return empty container if no data
    }
    
    final paytype237LcyStatus = _monitoringData!['paytype237']?['lcy']?['status'] ?? 'UNKNOWN';
    final paytype237UsdStatus = _monitoringData!['paytype237']?['usd']?['status'] ?? 'UNKNOWN';
    final paytype0LcyStatus = _monitoringData!['paytype0']?['lcy']?['status'] ?? 'UNKNOWN';
    final paytype0UsdStatus = _monitoringData!['paytype0']?['usd']?['status'] ?? 'UNKNOWN';
    final totalServices = 4;
    final upServices = (paytype237LcyStatus == 'UP' ? 1 : 0) + 
                      (paytype237UsdStatus == 'UP' ? 1 : 0) +
                      (paytype0LcyStatus == 'UP' ? 1 : 0) + 
                      (paytype0UsdStatus == 'UP' ? 1 : 0);
    final downServices = totalServices - upServices;
    final uptimePercentage = (upServices / totalServices * 100).round();
    
    return Row(
      children: [
        // Uptime Percentage
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFF059669).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 20,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'UPTIME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$uptimePercentage%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'System Availability',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Services Status
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.2),
                  const Color(0xFF1D4ED8).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.dns,
                      size: 20,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SERVICES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3B82F6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$upServices/$totalServices',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Active Services',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Response Time
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.2),
                  const Color(0xFF7C3AED).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 20,
                      color: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RESPONSE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B5CF6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_monitoringData!['paytype237']?['lcy']?['responseTime'] ?? 0}ms',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Avg Response Time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Next Scheduled Check
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF59E0B).withOpacity(0.2),
                  const Color(0xFFD97706).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 20,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NEXT CHECK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF59E0B),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getNextScheduledCheck().split(' ')[0] + '\n' + _getNextScheduledCheck().split(' ')[1],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Backend Schedule',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Build enhanced metrics overview dashboard
  Widget _buildMetricsOverview() {
    if (_monitoringData == null) {
      return Container(); // Return empty container if no data
    }
    
    final paytype237LcyStatus = _monitoringData!['paytype237']?['lcy']?['status'] ?? 'UNKNOWN';
    final paytype237UsdStatus = _monitoringData!['paytype237']?['usd']?['status'] ?? 'UNKNOWN';
    final paytype0LcyStatus = _monitoringData!['paytype0']?['lcy']?['status'] ?? 'UNKNOWN';
    final paytype0UsdStatus = _monitoringData!['paytype0']?['usd']?['status'] ?? 'UNKNOWN';
    final totalServices = 4;
    final upServices = (paytype237LcyStatus == 'UP' ? 1 : 0) + 
                      (paytype237UsdStatus == 'UP' ? 1 : 0) +
                      (paytype0LcyStatus == 'UP' ? 1 : 0) + 
                      (paytype0UsdStatus == 'UP' ? 1 : 0);
    final downServices = totalServices - upServices;
    final uptimePercentage = (upServices / totalServices * 100).round();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF475569).withOpacity(0.3),
          width: 1,
        ),
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
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insights,
                  size: 24,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'SYSTEM METRICS OVERVIEW',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Compact Metrics Grid
          Row(
            children: [
              // Uptime Percentage
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.2),
                        const Color(0xFF059669).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 20,
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'UPTIME',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$uptimePercentage%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'System Availability',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Services Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.2),
                        const Color(0xFF1D4ED8).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dns,
                            size: 20,
                            color: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SERVICES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF3B82F6),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$upServices',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          Text(
                            '/$totalServices',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Active Services',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Response Time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFF59E0B).withOpacity(0.2),
                        const Color(0xFFD97706).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            size: 20,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RESPONSE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF59E0B),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_monitoringData!['paytype237']?['lcy']?['responseTime'] ?? 'N/A'}ms',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Avg Response Time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build enhanced status card for a currency
  Widget _buildEnhancedStatusCard(String currency, String title, Map<String, dynamic> statusData, String iframeKey) {
    final isUp = (statusData['status'] ?? 'UNKNOWN') == 'UP';
    final resultCode = statusData['resultCode'];
    final errorMessage = statusData['errorMessage'] ?? '';
    final responseTime = statusData['responseTime'];
    final txnId = statusData['txnId'];
    
    // Add null safety for statusData
    if (statusData.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUp ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUp ? Colors.green : Colors.red).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUp ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUp ? Icons.check_circle : Icons.error,
                    color: isUp ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Currency: $currency',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUp ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUp ? 'UP' : 'DOWN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Compact Status details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Result Code',
                    resultCode?.toString() ?? 'N/A',
                    isUp ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    'Response Time',
                    responseTime != null ? '${responseTime}ms' : 'N/A',
                    isUp ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            
            // Transaction ID and embedded sandbox content
            if (isUp && txnId != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Transaction ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                            txnId.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Embedded Sandbox Content
              if (_isIframeRegistered) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.web,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Sandbox Environment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                      const SizedBox(height: 12),
                      Container(
                        height: 400,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: HtmlElementView(
                            viewType: iframeKey,
                          ),
                        ),
                    ),
                  ],
                ),
              ),
              ],
            ] else if (!isUp && errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Error Message',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
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
  }

  // Build detail item
  Widget _buildDetailItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Build enhanced historical data section
  Widget _buildEnhancedHistoricalSection() {
    if (_historicalData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF475569).withOpacity(0.3),
          width: 1,
        ),
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
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timeline,
                  size: 24,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'HISTORICAL PERFORMANCE DATA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Last 7 Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Compact Historical data table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF475569).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF0F172A).withOpacity(0.5),
            ),
            child: Column(
              children: [
                // Enhanced Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF475569).withOpacity(0.3),
                        const Color(0xFF64748B).withOpacity(0.3),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF475569).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'DATE / TIME',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'LCY STATUS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'USD STATUS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Data rows
                ..._historicalData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  final timestamp = _formatTimestamp(record['timestamp']);
                  
                  // Handle both old and new data structures for historical data
                  String lcyStatus;
                  String usdStatus;
                  
                  if (record.containsKey('paytype237')) {
                    // New structure
                    lcyStatus = record['paytype237']?['lcy']?['status'] ?? 'UNKNOWN';
                    usdStatus = record['paytype237']?['usd']?['status'] ?? 'UNKNOWN';
                  } else if (record.containsKey('lcy')) {
                    // Old structure
                    lcyStatus = record['lcy']?['status'] ?? 'UNKNOWN';
                    usdStatus = record['usd']?['status'] ?? 'UNKNOWN';
                  } else {
                    // Fallback
                    lcyStatus = 'UNKNOWN';
                    usdStatus = 'UNKNOWN';
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFF475569).withOpacity(0.3),
                          width: 1,
                      ),
                      ),
                      color: index % 2 == 0 
                          ? const Color(0xFF1E293B).withOpacity(0.3)
                          : const Color(0xFF334155).withOpacity(0.3),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            timestamp,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: lcyStatus == 'UP' 
                                    ? [
                                        const Color(0xFF10B981).withOpacity(0.2),
                                        const Color(0xFF059669).withOpacity(0.2),
                                      ]
                                    : [
                                        const Color(0xFFDC2626).withOpacity(0.2),
                                        const Color(0xFFB91C1C).withOpacity(0.2),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: lcyStatus == 'UP' 
                                    ? const Color(0xFF10B981).withOpacity(0.3)
                                    : const Color(0xFFDC2626).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  lcyStatus == 'UP' ? Icons.check_circle : Icons.error,
                                  size: 14,
                                  color: lcyStatus == 'UP' 
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 6),
                                Text(
                              lcyStatus,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: lcyStatus == 'UP' 
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFDC2626),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: usdStatus == 'UP' 
                                    ? [
                                        const Color(0xFF10B981).withOpacity(0.2),
                                        const Color(0xFF059669).withOpacity(0.2),
                                      ]
                                    : [
                                        const Color(0xFFDC2626).withOpacity(0.2),
                                        const Color(0xFFB91C1C).withOpacity(0.2),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: usdStatus == 'UP' 
                                    ? const Color(0xFF10B981).withOpacity(0.3)
                                    : const Color(0xFFDC2626).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  usdStatus == 'UP' ? Icons.check_circle : Icons.error,
                                  size: 14,
                                  color: usdStatus == 'UP' 
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 6),
                                Text(
                              usdStatus,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: usdStatus == 'UP' 
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFDC2626),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark dashboard background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact Dashboard Header
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E293B),
                          const Color(0xFF334155),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF475569).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Enhanced Icon with glow effect
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF1D4ED8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SANDBOX MONITORING DASHBOARD',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time system health monitoring and performance metrics',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            // Enhanced Last updated time
                            if (_monitoringData != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                              Text(
                                'Last Updated',
                                style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFF10B981),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _formatTimestamp(_monitoringData!['timestamp']),
                                style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            
                            // Enhanced Refresh button
                            AnimatedBuilder(
                              animation: _refreshAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _refreshAnimation.value * 2 * 3.14159,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF3B82F6),
                                          const Color(0xFF1D4ED8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  child: ElevatedButton.icon(
                                    onPressed: _isRefreshing ? null : _manualRefresh,
                                    icon: Icon(
                                      _isRefreshing ? Icons.hourglass_empty : Icons.refresh,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _isRefreshing ? 'Checking...' : 'Refresh Data',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                      ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Enhanced Loading state
                if (_isLoading) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E293B),
                          const Color(0xFF334155),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF475569).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Checking System Status...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Analyzing sandbox environment health',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  // Enhanced Error state
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF7F1D1D),
                          const Color(0xFF991B1B),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                          Icons.error_outline,
                          size: 48,
                            color: const Color(0xFFFCA5A5),
                        ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'System Error Detected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFDC2626),
                                const Color(0xFFB91C1C),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                          onPressed: _loadMonitoringData,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text(
                              'Retry Connection',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_monitoringData != null) ...[
                  // Metrics Overview Only
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E293B),
                          const Color(0xFF334155),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF475569).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildMetricsGrid(),
                  ),
                  const SizedBox(height: 12),
                  
                  // API Status Indicators
                  _buildApiStatusIndicators(),
                  const SizedBox(height: 12),
                  
                  // Detailed API Status
                  _buildDetailedApiStatus(),
                  const SizedBox(height: 12),
                  
                  // Mock Fail Testing Section - COMMENTED OUT
                  /*
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF7F1D1D),
                          const Color(0xFF991B1B),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withOpacity(0.2),
                          blurRadius: 8,
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.bug_report,
                                size: 20,
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'TESTING & DEBUG',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Trigger a mock failure to test the email notification system',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _triggerMockFail,
                          icon: const Icon(Icons.warning, size: 18),
                          label: const Text(
                            'TRIGGER MOCK FAIL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  */
                  
                  // Compact Status Cards
                  // Paytype 237 Status Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedStatusCard('414', 'LCY Paytype 237', _monitoringData!['paytype237']?['lcy'] ?? {}, _currentLcyViewFactory ?? 'lcy-sandbox-iframe'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEnhancedStatusCard('840', 'USD Paytype 237', _monitoringData!['paytype237']?['usd'] ?? {}, _currentUsdViewFactory ?? 'usd-sandbox-iframe'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Paytype 0 Status Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedStatusCard('414', 'LCY Paytype 0', _monitoringData!['paytype0']?['lcy'] ?? {}, _currentLcyViewFactoryPaytype0 ?? 'lcy-sandbox-iframe-paytype0'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEnhancedStatusCard('840', 'USD Paytype 0', _monitoringData!['paytype0']?['usd'] ?? {}, _currentUsdViewFactoryPaytype0 ?? 'usd-sandbox-iframe-paytype0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Compact v2.0 Status Cards
                  if (_monitoringDataV2 != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1E293B),
                            const Color(0xFF334155),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF475569).withOpacity(0.3),
                          width: 1,
                        ),
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.token,
                                  size: 20,
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'PAYIN v2.0 MONITORING',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Paytype 237 Status Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildEnhancedStatusCard('458', 'LCY v2.0 Paytype 237', _monitoringDataV2!['paytype237']?['lcy'] ?? {}, _currentLcyViewFactoryV2 ?? 'lcy-sandbox-iframe-v2'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEnhancedStatusCard('840', 'USD v2.0 Paytype 237', _monitoringDataV2!['paytype237']?['usd'] ?? {}, _currentUsdViewFactoryV2 ?? 'usd-sandbox-iframe-v2'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Paytype 0 Status Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildEnhancedStatusCard('458', 'LCY v2.0 Paytype 0', _monitoringDataV2!['paytype0']?['lcy'] ?? {}, _currentLcyViewFactoryV2Paytype0 ?? 'lcy-sandbox-iframe-v2-paytype0'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEnhancedStatusCard('840', 'USD v2.0 Paytype 0', _monitoringDataV2!['paytype0']?['usd'] ?? {}, _currentUsdViewFactoryV2Paytype0 ?? 'usd-sandbox-iframe-v2-paytype0'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Compact Historical data
                  _buildEnhancedHistoricalSection(),
                ],
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 