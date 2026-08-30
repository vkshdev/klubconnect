// Template for Firebase initialization options.
// Run `flutterfire configure` or copy this file to `lib/firebase_options.dart` with your credentials.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyExampleWebKey1234567890abcdef',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'klubconnect-demo',
    authDomain: 'klubconnect-demo.firebaseapp.com',
    storageBucket: 'klubconnect-demo.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyExampleAndroidKey1234567890abcdef',
    appId: '1:123456789012:android:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'klubconnect-demo',
    storageBucket: 'klubconnect-demo.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyExampleIosKey1234567890abcdef',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'klubconnect-demo',
    storageBucket: 'klubconnect-demo.firebasestorage.app',
    iosBundleId: 'com.klubconnect.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyExampleMacKey1234567890abcdef',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'klubconnect-demo',
    storageBucket: 'klubconnect-demo.firebasestorage.app',
    iosBundleId: 'com.klubconnect.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyExampleWindowsKey1234567890abcdef',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'klubconnect-demo',
    authDomain: 'klubconnect-demo.firebaseapp.com',
    storageBucket: 'klubconnect-demo.firebasestorage.app',
  );
}
