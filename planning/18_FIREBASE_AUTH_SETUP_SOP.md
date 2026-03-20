# Firebase Phone Auth Setup SOP (GigCredit)

This SOP gives the exact steps to enable real Firebase signup/login (Phone OTP) in the app.

## What You Need

1. A Google account with access to Firebase Console
2. Your Android package name from app config
3. SHA-1 and SHA-256 fingerprints for your debug/release keystores
4. For iOS builds: Apple bundle ID and APNs setup

## Keys/Files Required

1. Android config file: google-services.json
2. iOS config file: GoogleService-Info.plist (only if building iOS)
3. Firebase Web API key (not secret, auto-included in config files)

Note: Firebase API key is required for config, but it is not a private secret like a backend API token.

## Step-by-Step SOP

## Step 1 - Create Firebase Project

1. Go to Firebase Console: https://console.firebase.google.com
2. Click Create project
3. Set project name (for example: GigCredit)
4. Complete project creation

## Step 2 - Register Android App

1. Open Project Settings in Firebase
2. Under Your apps, click Android icon
3. Set Android package name exactly as appId
4. Current project default is com.example.gigcredit_app
5. Optionally set app nickname
6. Click Register app

## Step 3 - Add SHA Fingerprints (Required for Phone Auth)

1. In Firebase Project Settings, open your Android app
2. Add SHA-1 and SHA-256 fingerprints
3. To get debug SHA fingerprints on Windows, run:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

4. For release keystore, run keytool with your release keystore path and alias
5. Save fingerprints in Firebase app settings

## Step 4 - Download and Place google-services.json

1. Download google-services.json from Firebase Android app settings
2. Place file at:
   gigcredit_app/android/app/google-services.json

## Step 5 - Enable Phone Authentication

1. In Firebase Console, go to Build > Authentication
2. Click Get started
3. Open Sign-in method tab
4. Enable Phone provider
5. Save changes

## Step 6 - Configure App Build (Already Patched)

The project now includes Google Services plugin wiring:

1. android/build.gradle.kts contains com.google.gms.google-services plugin declaration
2. android/app/build.gradle.kts applies com.google.gms.google-services plugin

## Step 7 - Firestore Rules and Collection

Auth flow writes user profile docs in collection user_profiles.
Set temporary rules for development only:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /user_profiles/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 8 - Run the App

1. From gigcredit_app folder, run:

```powershell
flutter pub get
flutter run
```

2. Test login/signup with a real phone number
3. OTP verification should route to home on success

## Optional: Debug OTP Bypass (Local Only)

Real auth is default. Debug bypass is disabled unless explicitly enabled.
Use this only for local UI testing:

```powershell
flutter run --dart-define=GIGCREDIT_DEBUG_OTP_BYPASS=true --dart-define=GIGCREDIT_DEBUG_OTP_PHONE=9999999999
```

Then OTP screen accepts 000000 for that one test phone number.

## Common Issues and Fixes

1. Error: invalid-app-credential
   - Usually missing SHA-1/SHA-256 or stale google-services.json
2. Error: network-request-failed
   - Check internet/device connectivity
3. OTP never arrives
   - Check SIM/network, quota limits, and phone format
4. Firebase initialize errors
   - Verify google-services.json is in android/app and package name matches

## Security Notes

1. Do not rely on debug bypass in production builds
2. Use strict Firestore rules before release
3. Keep backend API keys separate from Firebase config
