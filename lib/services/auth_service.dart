import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'hive_service.dart';
import '../models/user_profile.dart';

/// Web Client ID из google-services.json (client_type: 3)
const _webClientId =
    '624904190292-rufut8a3q3r5guea0v3dgkmo0l68sh5n.apps.googleusercontent.com';

class AuthResult {
  final bool success;
  final String? error;
  final UserProfile? profile;

  const AuthResult.success(this.profile)
      : success = true,
        error = null;
  const AuthResult.failure(this.error)
      : success = false,
        profile = null;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(serverClientId: _webClientId);
  final HiveService _hiveService;

  AuthService(this._hiveService);

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────────
  // Получить Device ID (резервный идентификатор)
  // ─────────────────────────────────────────────────────────────────
  Future<String?> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return info.id; // уникальный Android ID
      }
      return null;
    } catch (e) {
      debugPrint('DeviceInfo error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Инициализация — вызывается при старте приложения
  // Логика:
  //   1. Есть Firebase сессия → восстанавливаем
  //   2. Нет сессии, есть профиль в Hive → анонимный вход
  //   3. Нет ничего → null (показываем онбординг)
  // ─────────────────────────────────────────────────────────────────
  Future<UserProfile?> initializeAuth() async {
    try {
      final firebaseUser = _auth.currentUser;
      final existingProfile = _hiveService.getProfile();

      if (firebaseUser != null) {
        debugPrint('Auth: восстановлена Firebase сессия ${firebaseUser.uid}');
        // Обновляем профиль актуальными данными из Firebase
        return await _syncProfileFromFirebase(firebaseUser, existingProfile);
      }

      if (existingProfile != null && existingProfile.firebaseUid != null) {
        // Профиль есть, но Firebase сессия истекла — входим анонимно
        debugPrint('Auth: профиль есть, Firebase сессии нет — анонимный вход');
        return await _signInAnonymously(existingProfile);
      }

      debugPrint('Auth: новый пользователь — нужен онбординг');
      return null;
    } catch (e) {
      debugPrint('Auth initializeAuth error: $e');
      return _hiveService.getProfile(); // fallback на локальный профиль
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Анонимный вход — создаёт Firebase UID без регистрации
  // ─────────────────────────────────────────────────────────────────
  Future<AuthResult> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user!;
      debugPrint('Auth: анонимный вход, uid=${user.uid}');

      final deviceId = await _getDeviceId();
      final profile = _hiveService.getProfile() ??
          UserProfile(isAnonymous: true);

      profile.firebaseUid = user.uid;
      profile.deviceId = deviceId;
      profile.isAnonymous = true;
      await _hiveService.saveProfile(profile);

      return AuthResult.success(profile);
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth signInAnonymously error: ${e.code}');
      return AuthResult.failure(_authErrorMessage(e.code));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Google Sign-In
  // Если пользователь был анонимным — привязываем Google к существующему
  // Firebase UID (история не теряется). Иначе — новый вход.
  // ─────────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult.failure('Вход отменён');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      User user;

      // Если анонимный — привязываем Google аккаунт к существующему UID
      if (_auth.currentUser?.isAnonymous == true) {
        try {
          final linked = await _auth.currentUser!.linkWithCredential(credential);
          user = linked.user!;
          debugPrint('Auth: анонимный аккаунт привязан к Google, uid=${user.uid}');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Google аккаунт уже привязан к другому UID — входим в него
            final result = await _auth.signInWithCredential(credential);
            user = result.user!;
            debugPrint('Auth: вход в существующий Google аккаунт, uid=${user.uid}');
          } else {
            rethrow;
          }
        }
      } else {
        final result = await _auth.signInWithCredential(credential);
        user = result.user!;
        debugPrint('Auth: Google Sign-In, uid=${user.uid}');
      }

      final deviceId = await _getDeviceId();
      final profile = _hiveService.getProfile() ?? UserProfile();

      profile.firebaseUid = user.uid;
      profile.deviceId = deviceId;
      profile.displayName = user.displayName ?? googleUser.displayName;
      profile.email = user.email ?? googleUser.email;
      profile.isAnonymous = false;
      await _hiveService.saveProfile(profile);

      return AuthResult.success(profile);
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth signInWithGoogle error: ${e.code}');
      return AuthResult.failure(_authErrorMessage(e.code));
    } catch (e) {
      debugPrint('Auth signInWithGoogle unexpected: $e');
      return AuthResult.failure('Не удалось войти через Google');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Выход
  // ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    debugPrint('Auth: выход выполнен');
  }

  // ─────────────────────────────────────────────────────────────────
  // Вспомогательные методы
  // ─────────────────────────────────────────────────────────────────

  Future<UserProfile> _signInAnonymously(UserProfile existing) async {
    try {
      final credential = await _auth.signInAnonymously();
      existing.firebaseUid = credential.user!.uid;
      existing.isAnonymous = true;
      await _hiveService.saveProfile(existing);
    } catch (e) {
      debugPrint('Auth _signInAnonymously fallback: $e');
    }
    return existing;
  }

  Future<UserProfile> _syncProfileFromFirebase(
      User firebaseUser, UserProfile? existing) async {
    final profile = existing ?? UserProfile();
    profile.firebaseUid = firebaseUser.uid;
    profile.isAnonymous = firebaseUser.isAnonymous;

    if (!firebaseUser.isAnonymous) {
      profile.displayName ??= firebaseUser.displayName;
      profile.email ??= firebaseUser.email;
    }

    if (profile.deviceId == null) {
      profile.deviceId = await _getDeviceId();
    }

    await _hiveService.saveProfile(profile);
    return profile;
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'Нет подключения к интернету';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже';
      case 'user-disabled':
        return 'Аккаунт заблокирован';
      case 'account-exists-with-different-credential':
        return 'Аккаунт уже существует с другим методом входа';
      default:
        return 'Ошибка аутентификации: $code';
    }
  }
}
