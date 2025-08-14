import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;

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
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  
  // Historical data (last 7 days) - Stored in memory only (not persisted)
  // This data is lost when the app is refreshed or closed
  // For persistent storage, we would need to implement local storage (SharedPreferences) or database
  List<Map<String, dynamic>> _historicalData = [];
  
  // Auto-refresh timer
  Timer? _autoRefreshTimer;

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
    
    // Set up auto-refresh every 5 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadMonitoringData();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _refreshController.dispose();
    _autoRefreshTimer?.cancel();
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
      final response = await http.post(
        Uri.parse('https://checksandboxstatus-amxcplfi6q-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _monitoringData = data['data'];
            _isLoading = false;
          });
          
          // Add to historical data
          _addToHistoricalData(data['data']);
        } else {
          setState(() {
            _errorMessage = data['error'] ?? 'Unknown error occurred';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Network error: ${error.toString()}';
        _isLoading = false;
      });
    }
  }

  // Manual refresh with animation
  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    _refreshController.forward();
    
    await _loadMonitoringData();
    
    _refreshController.reverse();
    
    setState(() {
      _isRefreshing = false;
    });
  }

  // Open sandbox URL with transaction ID
  void _openSandboxUrl(dynamic txnId) {
    final url = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$txnId';
    html.window.open(url, '_blank');
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
      'lcy': data['lcy'],
      'usd': data['usd'],
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

  // Build status card for a currency
  Widget _buildStatusCard(String currency, String title, Map<String, dynamic> statusData) {
    final isUp = statusData['status'] == 'UP';
    final resultCode = statusData['resultCode'];
    final errorMessage = statusData['errorMessage'];
    final responseTime = statusData['responseTime'];
    final txnId = statusData['txnId'];
    
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
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 20),
            
            // Status details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Result Code',
                    resultCode?.toString() ?? 'N/A',
                    isUp ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDetailItem(
                    'Response Time',
                    responseTime != null ? '${responseTime}ms' : 'N/A',
                    isUp ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            
            // Transaction ID and Error message
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            txnId.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openSandboxUrl(txnId.toString()),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Open Sandbox'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

  // Build historical data section
  Widget _buildHistoricalSection() {
    if (_historicalData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history,
                  size: 20,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Historical Data (Last 7 Days)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Historical data table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Date/Time',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'LCY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'USD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Data rows
                ..._historicalData.map((record) {
                  final timestamp = _formatTimestamp(record['timestamp']);
                  final lcyStatus = record['lcy']['status'];
                  final usdStatus = record['usd']['status'];
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            timestamp,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: lcyStatus == 'UP' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              lcyStatus,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: lcyStatus == 'UP' ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: usdStatus == 'UP' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              usdStatus,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: usdStatus == 'UP' ? Colors.green : Colors.red,
                              ),
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
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.monitor_heart,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SANDBOX MONITORING',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time status monitoring for sandbox environment',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            // Last updated time
                            if (_monitoringData != null) ...[
                              Text(
                                'Last Updated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatTimestamp(_monitoringData!['timestamp']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            
                            // Refresh button
                            AnimatedBuilder(
                              animation: _refreshAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _refreshAnimation.value * 2 * 3.14159,
                                  child: ElevatedButton.icon(
                                    onPressed: _isRefreshing ? null : _manualRefresh,
                                    icon: Icon(
                                      _isRefreshing ? Icons.hourglass_empty : Icons.refresh,
                                      size: 16,
                                    ),
                                    label: Text(_isRefreshing ? 'Checking...' : 'Refresh'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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
                const SizedBox(height: 24),
                
                // Loading state
                if (_isLoading) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Checking sandbox status...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  // Error state
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadMonitoringData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_monitoringData != null) ...[
                  // Status cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusCard('414', 'LCY Currency Check', _monitoringData!['lcy']),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatusCard('840', 'USD Currency Check', _monitoringData!['usd']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Historical data
                  _buildHistoricalSection(),
                ],
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 