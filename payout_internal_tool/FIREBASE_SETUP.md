# Firebase Authentication Setup

This guide will help you set up Firebase Authentication for the Payout Internal Tool.

## Prerequisites

1. A Firebase project
2. Firebase CLI installed (optional, for easier setup)

## Setup Steps

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or select an existing project
3. Follow the setup wizard

### 2. Enable Authentication

1. In your Firebase project console, go to "Authentication"
2. Click "Get started"
3. Go to the "Sign-in method" tab
4. Enable "Email/Password" authentication
5. Click "Save"

### 3. Create Users

1. In the Authentication section, go to "Users"
2. Click "Add user"
3. Enter email and password for authorized users
4. Repeat for all users who need access

### 4. Get Firebase Configuration

1. In your Firebase project console, go to "Project settings" (gear icon)
2. Scroll down to "Your apps" section
3. Click the web app icon (`</>`)
4. Register your app with a nickname (e.g., "Payout Internal Tool")
5. Copy the configuration object

### 5. Update Configuration Files

#### Update `lib/firebase_options.dart`:

Replace the placeholder values with your actual Firebase configuration:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_API_KEY',
  appId: 'YOUR_ACTUAL_APP_ID',
  messagingSenderId: 'YOUR_ACTUAL_SENDER_ID',
  projectId: 'YOUR_ACTUAL_PROJECT_ID',
  authDomain: 'YOUR_ACTUAL_PROJECT_ID.firebaseapp.com',
  storageBucket: 'YOUR_ACTUAL_PROJECT_ID.appspot.com',
);
```

#### Update `web/index.html`:

Replace the placeholder values in the Firebase configuration:

```javascript
const firebaseConfig = {
  apiKey: "YOUR_ACTUAL_API_KEY",
  authDomain: "YOUR_ACTUAL_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_ACTUAL_PROJECT_ID",
  storageBucket: "YOUR_ACTUAL_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_ACTUAL_SENDER_ID",
  appId: "YOUR_ACTUAL_APP_ID"
};
```

### 6. Install Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

### 7. Update Entry Point

The main entry point has been moved from `main.dart` to `app.dart`. Update your `web/index.html` to use the new entry point:

```html
<script>
  window.flutterConfiguration = {
    canvasKitBaseUrl: "/canvaskit/"
  };
</script>
<script src="flutter.js" defer></script>
<script>
  window.addEventListener('load', function(ev) {
    // Download main.dart.js
    _flutter.loader.loadEntrypoint({
      serviceWorker: {
        serviceWorkerVersion: serviceWorkerVersion,
      },
      onEntrypointLoaded: function(engineInitializer) {
        engineInitializer.initializeEngine().then(function(appRunner) {
          appRunner.runApp();
        });
      }
    });
  });
</script>
```

### 8. Test the Setup

1. Run the application: `flutter run -d chrome`
2. You should see the login screen
3. Try logging in with the credentials you created in step 3

## Security Rules

For production, consider implementing additional security measures:

1. **Domain Restrictions**: In Firebase Console > Authentication > Settings > Authorized domains, add your domain
2. **Email Verification**: Enable email verification in Authentication > Sign-in method > Email/Password
3. **Password Policies**: Set minimum password requirements
4. **Rate Limiting**: Configure rate limiting for login attempts

## Troubleshooting

### Common Issues:

1. **"Firebase not initialized"**: Check that your Firebase configuration is correct
2. **"User not found"**: Make sure you've created users in Firebase Console
3. **"Invalid email"**: Check email format and domain restrictions
4. **CORS errors**: Ensure your domain is added to authorized domains in Firebase

### Debug Mode:

To enable debug logging, add this to your `main()` function in `app.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable debug mode
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable debug logging
  if (kDebugMode) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }
  
  runApp(const MyApp());
}
```

## Features

- **Email/Password Authentication**: Users must sign in with email and password
- **Session Management**: Users stay logged in until they sign out
- **User Menu**: Shows current user email and sign out option
- **Protected Routes**: All tool functionality is protected behind authentication
- **Error Handling**: Comprehensive error messages for authentication failures

## Customization

You can customize the authentication flow by modifying:

- `lib/services/auth_service.dart`: Authentication logic
- `lib/screens/login_screen.dart`: Login UI
- `lib/app.dart`: App structure and navigation 