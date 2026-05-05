// AUTO-GENERATED from google-services.json
// Project: aquatrack-7dbfb

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not configured');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not supported for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBth_A2DMCkfNKTz9iWBkT2E8RPZLwyfcs',
    appId:             '1:624904190292:android:a144397f5cf0cf5f6a30c1',
    messagingSenderId: '624904190292',
    projectId:         'aquatrack-7dbfb',
    storageBucket:     'aquatrack-7dbfb.firebasestorage.app',
  );
}
