# Sandbox Monitoring Feature

## Overview

The Sandbox Monitoring feature provides real-time status monitoring for the sandbox environment by automatically checking both LCY (currency: 414) and USD (currency: 840) currency endpoints.

## Features

### 1. Automated Daily Checks
- **LCY Currency Check** (currency: 414)
- **USD Currency Check** (currency: 840)
- Each check calls the sandbox API endpoint: `https://sandbox.codapayments.com/airtime/api/restful/v1.0/Payment/init.json`

### 2. Status Monitoring
- **UP Status**: When `resultCode: 0` is returned
- **DOWN Status**: When `resultCode` is not 0, API call fails, or no response is received
- Displays detailed error messages and response times

### 3. Real-time Dashboard
- Modern, metric-style UI with color-coded status indicators
- Green for UP status, Red for DOWN status
- Shows last checked time and response times
- Manual "Refresh" button for on-demand checks

### 4. Historical Data
- Keeps track of the last 7 days of status checks
- Displays trend data in a table format
- Helps identify patterns and recurring issues
- **Note**: Data is stored in memory only and will be lost when the app is refreshed

## API Endpoint

### Firebase Function
```
POST https://us-central1-codapay-webhook.cloudfunctions.net/checkSandboxStatus
Content-Type: application/json
```

### Request Body
```json
{}
```

### Response Format
```json
{
  "success": true,
  "data": {
    "timestamp": "2025-08-12T10:44:00.839Z",
    "lcy": {
      "status": "UP",
      "resultCode": 0,
      "responseTime": 1129
    },
    "usd": {
      "status": "UP", 
      "resultCode": 0,
      "responseTime": 912
    }
  }
}
```

## Sandbox API Details

### Request Format
Each currency check sends the following request to the sandbox:

```json
{
  "initRequest": {
    "apiKey": "d2cf91e6b28efa6243d7a4c4ac49305c6",
    "orderId": "O{timestamp}_{random}",
    "country": 414,
    "currency": 414, // or 840 for USD
    "payType": 475,
    "items": [
      {
        "code": "com.diamond_mt_id_25",
        "name": "25+3",
        "price": "1",
        "type": 1
      }
    ],
    "profile": {
      "entry": [
        {
          "key": "user_id",
          "value": "12345"
        }
      ]
    }
  }
}
```

### Expected Response (UP Status)
```json
{
  "initResult": {
    "resultCode": 0,
    "txnId": 7549926045936067591
  }
}
```

## Usage

### Accessing the Monitoring Dashboard
1. Open the Payout Internal Tool application
2. Navigate to the "Monitoring" tab using the bottom navigation bar
3. The dashboard will automatically load the current status
4. Use the "Refresh" button to manually trigger new checks

### Interpreting Results
- **Green UP Status**: Sandbox environment is healthy and responding correctly
- **Red DOWN Status**: Issues detected - check error messages for details
- **Response Time**: Shows how quickly the sandbox responds (in milliseconds)
- **Historical Data**: Review past 7 days to identify patterns
- **Timezone**: All timestamps are displayed in GMT+8 (Singapore time)

### Auto-refresh
- The dashboard automatically refreshes every 5 minutes
- Manual refresh is always available via the refresh button

## Error Handling

### Common Error Scenarios
1. **Network Timeout**: "No response from sandbox environment"
2. **HTTP Errors**: "HTTP {status}: {statusText}"
3. **API Errors**: Shows the specific error message from the sandbox API
4. **Invalid Response**: "Unknown error" when response format is unexpected

### Troubleshooting
- Check VPN connection if accessing from outside the office
- Verify sandbox environment is running
- Contact the development team if issues persist

## Technical Implementation

### Frontend (Flutter)
- `SandboxMonitoringScreen` widget handles the UI
- Uses HTTP package for API calls
- Implements auto-refresh timer
- Stores historical data in memory (not persisted)
- Converts timestamps to GMT+8 timezone for display

### Backend (Firebase Functions)
- `checkSandboxStatus` function handles API calls
- Uses Node.js fetch API for sandbox requests
- Implements proper error handling and CORS
- Returns structured response with status details

## Security Considerations

- API calls are made server-side via Firebase Functions
- No sensitive credentials exposed in frontend code
- CORS properly configured for cross-origin requests
- Error messages sanitized to prevent information leakage

## Data Storage

### Current Implementation
- Historical data is stored **in memory only**
- Data is lost when the app is refreshed or closed
- Limited to the current session

### Persistent Storage Options
For production use, consider implementing one of these storage solutions:

1. **SharedPreferences** (Simple key-value storage)
   - Good for small amounts of data
   - Easy to implement
   - Limited storage capacity

2. **SQLite Database** (Local database)
   - Good for complex data structures
   - Supports queries and relationships
   - Requires more setup

3. **Cloud Firestore** (Cloud database)
   - Persistent across devices
   - Real-time synchronization
   - Requires Firebase setup

4. **Local Files** (JSON/CSV files)
   - Simple file-based storage
   - Good for data export/import
   - Limited query capabilities

## Future Enhancements

- Email notifications for status changes
- Slack integration for alerts
- Extended historical data (30+ days)
- Performance metrics and trends
- Custom alert thresholds
- Integration with other monitoring tools
- **Persistent data storage** (implement one of the options above) 