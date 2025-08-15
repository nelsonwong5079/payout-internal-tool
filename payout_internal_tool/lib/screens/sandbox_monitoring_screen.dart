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
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  
  // Historical data (last 7 days) - Stored in memory only (not persisted)
  // This data is lost when the app is refreshed or closed
  // For persistent storage, we would need to implement local storage (SharedPreferences) or database
  List<Map<String, dynamic>> _historicalData = [];
  
  // Auto-refresh timer
  Timer? _autoRefreshTimer;

  // Iframe view registration - for embedding sandbox content
  bool _isIframeRegistered = false;
  String? _currentLcyViewFactory;
  String? _currentUsdViewFactory;

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
          
          // Register iframe views when data is loaded and transaction IDs are available
          _registerIframeViews();
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
    });
    
    await _loadMonitoringData();
    
    _refreshController.reverse();
    
    setState(() {
      _isRefreshing = false;
    });
  }

  // Register iframe views for embedding sandbox content with security restrictions
  void _registerIframeViews() {
    if (_isIframeRegistered || _monitoringData == null) return;
    
    final lcyTxnId = _monitoringData!['lcy']['txnId'];
    final usdTxnId = _monitoringData!['usd']['txnId'];
    
    // Generate unique view factory names with timestamp to ensure fresh content
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final lcyViewFactoryName = 'lcy-sandbox-iframe-$timestamp';
    final usdViewFactoryName = 'usd-sandbox-iframe-$timestamp';
    
    if (lcyTxnId != null) {
      final lcyUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$lcyTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        lcyViewFactoryName,
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
    
    if (usdTxnId != null) {
      final usdUrl = 'https://sandbox.codapayments.com/airtime/begin?type=3&txn_id=$usdTxnId';
      ui_web.platformViewRegistry.registerViewFactory(
        usdViewFactoryName,
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
      _currentLcyViewFactory = lcyViewFactoryName;
      _currentUsdViewFactory = usdViewFactoryName;
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

  // Build enhanced metrics overview dashboard
  Widget _buildMetricsOverview() {
    final lcyStatus = _monitoringData!['lcy']['status'];
    final usdStatus = _monitoringData!['usd']['status'];
    final totalServices = 2;
    final upServices = (lcyStatus == 'UP' ? 1 : 0) + (usdStatus == 'UP' ? 1 : 0);
    final downServices = totalServices - upServices;
    final uptimePercentage = (upServices / totalServices * 100).round();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
          const SizedBox(height: 24),
          
          // Metrics Grid
          Row(
            children: [
              // Uptime Percentage
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                        '${_monitoringData!['lcy']['responseTime'] ?? 'N/A'}ms',
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
      padding: const EdgeInsets.all(28),
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
          const SizedBox(height: 16),
          
          // Enhanced Historical data table
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
                  final lcyStatus = record['lcy']['status'];
                  final usdStatus = record['usd']['status'];
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
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
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Dashboard Header
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(28),
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
                                padding: const EdgeInsets.all(20),
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
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SANDBOX MONITORING DASHBOARD',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Real-time system health monitoring and performance metrics',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
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
                            const SizedBox(height: 16),
                            
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
                    padding: const EdgeInsets.all(32),
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
                        const SizedBox(height: 20),
                        Text(
                          'System Error Detected',
                          style: TextStyle(
                            fontSize: 20,
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
                        const SizedBox(height: 24),
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
                  // Enhanced Metrics Dashboard
                  _buildMetricsOverview(),
                  const SizedBox(height: 24),
                  
                  // Enhanced Status Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedStatusCard('414', 'LCY Currency Check', _monitoringData!['lcy'], _currentLcyViewFactory ?? 'lcy-sandbox-iframe'),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildEnhancedStatusCard('840', 'USD Currency Check', _monitoringData!['usd'], _currentUsdViewFactory ?? 'usd-sandbox-iframe'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Enhanced Historical data
                  _buildEnhancedHistoricalSection(),
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