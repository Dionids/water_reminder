import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'hive_service.dart';
import 'api_service.dart';
import '../models/user_profile.dart';

/// Web Client ID (client_type: 3) из google-services.json
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

  /// FIX: На Android используем clientId, не serverClientId
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  final HiveService _hiveService;
  final ApiService _apiService;

  AuthService(this._hiveService, this._apiService);

  User? get currentUser     => _auth.currentUser;
  bool get isSignedIn       => currentUser != null;
  bool get isAnonymous      => currentUser?.isAnonymous ?? true;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Device ID ──────────────────────────────────────────────────

  Future<String?> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return info.id;
      }
      return null;
    } catch (e) {
      debugPrint('DeviceInfo error: $e');
      return null;
    }
  }

  // ── Инициализация при старте ───────────────────────────────────

  Future<UserProfile?> initializeAuth() async {
    try {
      final firebaseUser   = _auth.currentUser;
      final existingProfile = _hiveService.getProfile();

      if (firebaseUser != null) {
        debugPrint('Auth: восстановлена сессия ${firebaseUser.uid}');
        return await _syncProfileFromFirebase(firebaseUser, existingProfile);
      }

      // Firebase сессии нет, но профиль с uid есть → перевходим анонимно
      if (existingProfile != null && existingProfile.firebaseUid != null) {
        debugPrint('Auth: сессия истекла, перевход анонимно');
        return await _reSignInAnonymously(existingProfile);
      }

      debugPrint('Auth: новый пользователь');
      return null;
    } catch (e) {
      debugPrint('Auth initializeAuth error: $e');
      return _hiveService.getProfile();
    }
  }

  // ── Анонимный вход ─────────────────────────────────────────────

  Future<AuthResult> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user       = credential.user!;
      debugPrint('Auth: анонимный uid=${user.uid}');

      final deviceId = await _getDeviceId();
      final profile  = _hiveService.getProfile() ?? UserProfile(isAnonymous: true);

      profile
        ..firebaseUid = user.uid
        ..deviceId    = deviceId
        ..isAnonymous = true;

      await _hiveService.saveProfile(profile);

      // Регистрируем на сервере
      await _registerOnServer(profile);

      return AuthResult.success(profile);
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth anon error: ${e.code}');
      return AuthResult.failure(_errorMessage(e.code));
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────

  Future<AuthResult> signInWithGoogle() async {
    try {
      // Сбрасываем предыдущую Google сессию чтобы показать picker аккаунтов
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult.failure('Вход отменён');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      User user;

      if (_auth.currentUser?.isAnonymous == true) {
        // Привязываем Google к анонимному аккаунту — uid сохраняется
        try {
          final linked = await _auth.currentUser!.linkWithCredential(credential);
          user = linked.user!;
          debugPrint('Auth: анонимный → Google uid=${user.uid}');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Этот Google аккаунт уже есть в Firebase — входим в него
            final result = await _auth.signInWithCredential(credential);
            user = result.user!;
            debugPrint('Auth: существующий Google аккаунт uid=${user.uid}');
          } else {
            rethrow;
          }
        }
      } else {
        final result = await _auth.signInWithCredential(credential);
        user = result.user!;
        debugPrint('Auth: Google Sign-In uid=${user.uid}');
      }

      final deviceId = await _getDeviceId();
      final profile  = _hiveService.getProfile() ?? UserProfile();

      profile
        ..firebaseUid = user.uid
        ..deviceId    = deviceId
        ..displayName = user.displayName ?? googleUser.displayName
        ..email       = user.email ?? googleUser.email
        ..isAnonymous = false;

      await _hiveService.saveProfile(profile);

      // Регистрируем / обновляем на сервере
      await _registerOnServer(profile);

      return AuthResult.success(profile);
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth Google error: ${e.code} — ${e.message}');
      return AuthResult.failure(_errorMessage(e.code));
    } catch (e) {
      debugPrint('Auth Google unexpected: $e');
      return AuthResult.failure('Не удалось войти через Google');
    }
  }

  // ── Выход ──────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _hiveService.clearProfile();
    debugPrint('Auth: выход выполнен');
  }

  // ── Приватные методы ───────────────────────────────────────────

  Future<void> _registerOnServer(UserProfile profile) async {
    if (profile.firebaseUid == null) return;
    try {
      await _apiService.upsertUser(
        firebaseUid:  profile.firebaseUid!,
        deviceId:     profile.deviceId,
        displayName:  profile.displayName,
        email:        profile.email,
        isAnonymous:  profile.isAnonymous,
        weightKg:     profile.weight,
        age:          profile.age,
      );
    } catch (e) {
      // Офлайн — не критично, попробуем при следующей синхронизации
      debugPrint('Auth _registerOnServer offline: $e');
    }
  }

  Future<UserProfile> _reSignInAnonymously(UserProfile existing) async {
    try {
      final credential = await _auth.signInAnonymously();
      existing.firebaseUid = credential.user!.uid;
      existing.isAnonymous = true;
      await _hiveService.saveProfile(existing);
    } catch (e) {
      debugPrint('Auth _reSignInAnonymously error: $e');
    }
    return existing;
  }

  Future<UserProfile> _syncProfileFromFirebase(
      User firebaseUser, UserProfile? existing) async {
    final profile = existing ?? UserProfile();

    profile
      ..firebaseUid = firebaseUser.uid
      ..isAnonymous = firebaseUser.isAnonymous;

    if (!firebaseUser.isAnonymous) {
      profile.displayName ??= firebaseUser.displayName;
      profile.email ??= firebaseUser.email;
    }

    profile.deviceId ??= await _getDeviceId();
    await _hiveService.saveProfile(profile);
    return profile;
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'Нет подключения к интернету';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже';
      case 'user-disabled':
        return 'Аккаунт заблокирован';
      case 'account-exists-with-different-credential':
        return 'Аккаунт уже существует с другим методом входа';
      case 'sign_in_canceled':
      case 'canceled':
        return 'Вход отменён';
      default:
        return 'Ошибка: $code';
    }
  }
}
