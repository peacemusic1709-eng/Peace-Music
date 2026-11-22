import 'dart:convert';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import '../models/media_Item_builder.dart';
import '../models/peace_user.dart';
import '../models/playlist.dart';
import '../ui/widgets/snackbar.dart';
import 'downloader.dart';

class PeaceAuthService extends GetxService {
  final currentUser = Rxn<PeaceUser>();
  final isLoggedIn = false.obs;
  final isGuest = false.obs;
  final isSyncing = false.obs;
  final Map<String, String> _activeOtps = {};
  bool hasShownLaunchOnboarding = false;

  static const String googleScriptWebhookUrl =
      "https://script.google.com/macros/s/AKfycbw5Zad-M0kzVaHh-mHEcLcj957faphlOqRqynJMWpYIS1prx_89pZpB9PrHPskyZFju/exec";
  static const String vpsBaseUrl = "http://95.135.166.138:5055";

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<bool> triggerGoogleDeviceSignIn() async {
    // 1. Android OS Native Account Picker (shows system Google accounts and returns selected Gmail with 0 setup)
    try {
      const channel = MethodChannel("peace_music/account_picker");
      final email = await channel.invokeMethod<String>("pickDeviceGoogleAccount");
      if (email != null && email.trim().isNotEmpty) {
        final cleanEmail = email.trim().toLowerCase();
        final name = cleanEmail.split('@').first;
        final capitalized = name.isNotEmpty ? name[0].toUpperCase() + name.substring(1) : "Google User";
        await loginWithGoogle(cleanEmail, capitalized);
        return true;
      }
    } catch (e) {
      debugPrint("Native AccountManager picker: $e");
    }

    // 2. GoogleSignIn Plugin Fallback
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account != null) {
        final email = account.email;
        final name = account.displayName ?? email.split('@').first;
        final photoUrl = account.photoUrl;

        await loginWithGoogle(email, name, photoUrl: photoUrl);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Native GoogleSignIn error: $e");
      return false;
    }
  }

  Box get _authBox => Hive.box("PeaceAuth");

  Map<String, dynamic> _getRegisteredUsers() {
    try {
      if (_authBox.containsKey("registeredUsers")) {
        final raw = _authBox.get("registeredUsers");
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _saveUserToRegistry(PeaceUser user) async {
    try {
      final registry = _getRegisteredUsers();
      final json = user.toJson();
      if (user.email.isNotEmpty) registry[user.email.toLowerCase()] = json;
      if (user.username.isNotEmpty) registry[user.username.toLowerCase()] = json;
      registry[user.userId] = json;
      await _authBox.put("registeredUsers", registry);
    } catch (e) {
      debugPrint("Error saving to user registry: $e");
    }
  }

  String generateUniqueUsername(String fullName) {
    final clean = fullName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final base = clean.isEmpty ? "peace_user" : clean;
    final randomNum = 100 + Random().nextInt(900);
    return "@${base}_$randomNum";
  }

  String? getOtpForEmail(String email) => _activeOtps[email.trim().toLowerCase()];

  Future<bool> isEmailRegistered(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final res = await Dio().post(
        "$vpsBaseUrl/check-email",
        data: {"email": cleanEmail},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        return res.data["exists"] == true;
      }
    } catch (e) {
      debugPrint("check-email error: $e");
    }
    final registry = _getRegisteredUsers();
    return registry.containsKey(cleanEmail);
  }

  bool isValidEmail(String email) {
    final clean = email.trim().toLowerCase();
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(clean);
  }

  Future<String> sendOtpToEmail(String email, {String purpose = "Verification"}) async {
    final cleanEmail = email.trim().toLowerCase();
    final otp = (100000 + Random().nextInt(900000)).toString();
    _activeOtps[cleanEmail] = otp;

    // Send real email via Harsh's Google Apps Script Web App!
    final webhookUrl = _authBox.get("mailWebhookUrl", defaultValue: googleScriptWebhookUrl);
    if (webhookUrl != null && webhookUrl.toString().trim().isNotEmpty) {
      try {
        await Dio().post(
          webhookUrl.toString().trim(),
          data: {
            "to": cleanEmail,
            "subject": "Your Peace Music verification code is $otp",
            "body": "Your Peace Music verification code is: $otp\n\nValid for 10 minutes.\n\nPeace Music • Lossless Audio Streaming • Made by Harsh",
            "otp": otp,
          },
          options: Options(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            headers: {"Content-Type": "application/json"},
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      } catch (e) {
        debugPrint("Webhook dispatch error: $e");
      }
    }

    showCustomSnackBar(
      "OTP Code: $otp (Sent to $cleanEmail)",
      title: "Gmail $purpose OTP",
      duration: const Duration(seconds: 10),
    );

    return otp;
  }

  bool verifyOtp(String email, String enteredOtp) {
    final cleanEmail = email.trim().toLowerCase();
    if (_activeOtps.containsKey(cleanEmail)) {
      final valid = _activeOtps[cleanEmail] == enteredOtp.trim();
      if (valid) {
        _activeOtps.remove(cleanEmail);
        return true;
      }
    }
    return false;
  }

  Future<bool> registerUser({
    required String name,
    required String email,
    required String username,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isEmpty ? "User" : name.trim();
    var cleanUsername = username.trim().toLowerCase();
    if (!cleanUsername.startsWith('@')) cleanUsername = '@$cleanUsername';

    try {
      final res = await Dio().post(
        "$vpsBaseUrl/register",
        data: {
          "name": cleanName,
          "email": cleanEmail,
          "username": cleanUsername,
          "password": password,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (res.statusCode == 201 && res.data is Map && res.data["success"] == true) {
        final userData = res.data["user"];
        final user = PeaceUser.fromJson(Map<String, dynamic>.from(userData)).copyWith(
          downloadedSongIds: _getLocalDownloadedSongIds(),
        );

        await _saveUserToRegistry(user);
        await _authBox.put("currentUser", user.toJson());
        currentUser.value = user;
        isLoggedIn.value = true;
        isGuest.value = false;

        await syncWithCloud(showNotice: false);

        showCustomSnackBar(
          "Account ban gaya! Welcome, $cleanName ($cleanUsername)",
          title: "Sign Up Successful 🎉",
          duration: const Duration(seconds: 4),
        );
        return true;
      } else {
        final msg = res.data is Map && res.data["message"] != null
            ? res.data["message"].toString()
            : "Sign Up fail hua. Kripya check karein.";
        showCustomSnackBar(msg, title: "Sign Up Failed");
        return false;
      }
    } catch (e) {
      debugPrint("VPS Register error: $e");
      if (e is DioException && e.response?.data is Map && e.response?.data["message"] != null) {
        showCustomSnackBar(e.response!.data["message"].toString(), title: "Sign Up Error");
        return false;
      }
      // Offline fallback
      final registry = _getRegisteredUsers();
      if (registry.containsKey(cleanEmail)) {
        showCustomSnackBar("Yeh Gmail pehle se registered hai! Login karein.", title: "Already Registered");
        return false;
      }
      final userId = "user_${DateTime.now().millisecondsSinceEpoch}";
      final user = PeaceUser(
        userId: userId,
        name: cleanName,
        username: cleanUsername,
        email: cleanEmail,
        password: password,
        isGuest: false,
        createdAt: DateTime.now(),
        lastSyncedAt: DateTime.now(),
        downloadedSongIds: _getLocalDownloadedSongIds(),
      );
      await _saveUserToRegistry(user);
      await _authBox.put("currentUser", user.toJson());
      currentUser.value = user;
      isLoggedIn.value = true;
      isGuest.value = false;
      showCustomSnackBar(
        "Account ban gaya (Offline)! Welcome, $cleanName",
        title: "Sign Up Successful",
        duration: const Duration(seconds: 4),
      );
      return true;
    }
  }

  Future<bool> loginWithCredentials({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim().toLowerCase();

    try {
      final res = await Dio().post(
        "$vpsBaseUrl/login",
        data: {
          "identifier": cleanId,
          "password": password,
          "otpVerified": false,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (res.statusCode == 200 && res.data is Map && res.data["success"] == true) {
        final userData = res.data["user"];
        final savedUser = PeaceUser.fromJson(Map<String, dynamic>.from(userData)).copyWith(
          downloadedSongIds: _getLocalDownloadedSongIds(),
        );

        await _saveUserToRegistry(savedUser);
        await _authBox.put("currentUser", savedUser.toJson());
        currentUser.value = savedUser;
        isLoggedIn.value = true;
        isGuest.value = false;

        // Restore user's cloud library from VPS!
        if (res.data["cloudData"] is Map) {
          await _restoreCloudData(Map<String, dynamic>.from(res.data["cloudData"]));
        }

        showCustomSnackBar("Welcome back, ${savedUser.name}!", title: "Login Successful 🎉");
        return true;
      } else {
        final msg = res.data is Map && res.data["message"] != null
            ? res.data["message"].toString()
            : "Login fail hua. Check credentials.";
        showCustomSnackBar(msg, title: "Login Failed");
        return false;
      }
    } catch (e) {
      debugPrint("VPS Login error: $e");
      if (e is DioException && e.response?.data is Map && e.response?.data["message"] != null) {
        showCustomSnackBar(e.response!.data["message"].toString(), title: "Login Error");
        return false;
      }
      // Offline fallback
      final registry = _getRegisteredUsers();
      if (registry.containsKey(cleanId)) {
        final userData = registry[cleanId];
        if (userData is Map) {
          final savedUser = PeaceUser.fromJson(userData);
          if (savedUser.password.isNotEmpty && savedUser.password != password) {
            showCustomSnackBar("Galat password! Kripya dobara try karein.", title: "Incorrect Password");
            return false;
          }
          await _authBox.put("currentUser", savedUser.toJson());
          currentUser.value = savedUser;
          isLoggedIn.value = true;
          isGuest.value = false;
          showCustomSnackBar("Welcome back, ${savedUser.name}! (Offline)", title: "Login Successful");
          return true;
        }
      }
      showCustomSnackBar("Koi account nahi mila ya internet connection nahi hai.", title: "Login Failed");
      return false;
    }
  }

  Future<bool> loginWithEmailOtp({
    required String email,
    required String enteredOtp,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!verifyOtp(cleanEmail, enteredOtp)) {
      showCustomSnackBar("Galat OTP code! Kripya check karein.", title: "Invalid OTP");
      return false;
    }

    try {
      final res = await Dio().post(
        "$vpsBaseUrl/login",
        data: {
          "identifier": cleanEmail,
          "otpVerified": true,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (res.statusCode == 200 && res.data is Map && res.data["success"] == true) {
        final userData = res.data["user"];
        final user = PeaceUser.fromJson(Map<String, dynamic>.from(userData)).copyWith(
          downloadedSongIds: _getLocalDownloadedSongIds(),
        );

        await _saveUserToRegistry(user);
        await _authBox.put("currentUser", user.toJson());
        currentUser.value = user;
        isLoggedIn.value = true;
        isGuest.value = false;

        if (res.data["cloudData"] is Map) {
          await _restoreCloudData(Map<String, dynamic>.from(res.data["cloudData"]));
        }

        showCustomSnackBar("Welcome back, ${user.name}!", title: "Login Successful 🎉");
        return true;
      }
      if (e is DioException && e.response?.data is Map && e.response?.data["message"] != null) {
        showCustomSnackBar(e.response!.data["message"].toString(), title: "Login Error");
        return false;
      }
    }

    // Local fallback check
    final registry = _getRegisteredUsers();
    if (registry.containsKey(cleanEmail)) {
      final userData = registry[cleanEmail];
      if (userData is Map) {
        final savedUser = PeaceUser.fromJson(userData);
        await _authBox.put("currentUser", savedUser.toJson());
        currentUser.value = savedUser;
        isLoggedIn.value = true;
        isGuest.value = false;
        showCustomSnackBar("Welcome back, ${savedUser.name}!", title: "Login Successful 🎉");
        return true;
      }
    }

    showCustomSnackBar("Koi account nahi mila is email se! Kripya Sign Up karein.", title: "Account Not Found");
    return false;
  }

  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final res = await Dio().post(
        "$vpsBaseUrl/reset-password",
        data: {
          "email": cleanEmail,
          "newPassword": newPassword,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (res.statusCode == 200 && res.data is Map && res.data["success"] == true) {
        final registry = _getRegisteredUsers();
        if (registry.containsKey(cleanEmail)) {
          final userData = registry[cleanEmail];
          if (userData is Map) {
            final saved = PeaceUser.fromJson(userData).copyWith(password: newPassword);
            await _saveUserToRegistry(saved);
          }
        }
        showCustomSnackBar("Aapka password badal gaya hai! Ab naye password se login karein.", title: "Password Reset Complete 🎉");
        return true;
      }
    } catch (e) {
      debugPrint("VPS resetPassword error: $e");
    }

    // Fallback locally
    final registry = _getRegisteredUsers();
    if (registry.containsKey(cleanEmail)) {
      final userData = registry[cleanEmail];
      if (userData is Map) {
        final savedUser = PeaceUser.fromJson(userData).copyWith(password: newPassword);
        await _saveUserToRegistry(savedUser);
        if (currentUser.value?.email == cleanEmail) {
          currentUser.value = savedUser;
          await _authBox.put("currentUser", savedUser.toJson());
        }
        showCustomSnackBar("Aapka password badal gaya hai! Ab naye password se login karein.", title: "Password Reset Complete");
        return true;
      }
    }

    showCustomSnackBar("Yeh Gmail kisi account se juda nahi hai ya server error hai.", title: "Reset Failed");
    return false;
  }

  void showCustomSnackBar(String message, {String? title, Duration? duration}) {
    final ctx = Get.context;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        snackbar(
          ctx,
          title != null && title.isNotEmpty ? "$title\n$message" : message,
          size: SanckBarSize.BIG,
          duration: duration ?? const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadUserFromStorage();
  }

  void _loadUserFromStorage() {
    try {
      if (_authBox.containsKey("currentUser")) {
        final data = _authBox.get("currentUser");
        if (data is Map) {
          final user = PeaceUser.fromJson(data);
          currentUser.value = user;
          isLoggedIn.value = true;
          isGuest.value = user.isGuest;
        }
      }
    } catch (e) {
      debugPrint("Error loading peace user: $e");
    }
  }

  Future<void> loginAsGuest([String fullName = "Guest User"]) async {
    // Check if an existing persistent guest profile already exists on this phone
    if (_authBox.containsKey("savedGuestProfile")) {
      try {
        final raw = _authBox.get("savedGuestProfile");
        if (raw is Map) {
          final existing = PeaceUser.fromJson(Map<String, dynamic>.from(raw));
          await _authBox.put("currentUser", existing.toJson());
          currentUser.value = existing;
          isLoggedIn.value = true;
          isGuest.value = true;
          showCustomSnackBar(
            "Welcome back, ${existing.name}!",
            title: "Guest Session Restored",
            duration: const Duration(seconds: 3),
          );
          return;
        }
      } catch (_) {}
    }

    final cleanName = fullName.trim().isEmpty ? "Guest User" : fullName.trim();
    final guestId = "guest_${DateTime.now().millisecondsSinceEpoch}";
    final guestUsername = "@guest_${100 + Random().nextInt(900)}";

    // Capture currently downloaded songs
    final currentDownloads = _getLocalDownloadedSongIds();

    final user = PeaceUser(
      userId: guestId,
      name: cleanName,
      username: guestUsername,
      email: "",
      isGuest: true,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      downloadedSongIds: currentDownloads,
    );

    // Save permanently on the device so logouts don't wipe it
    await _authBox.put("savedGuestProfile", user.toJson());
    await _authBox.put("currentUser", user.toJson());
    currentUser.value = user;
    isLoggedIn.value = true;
    isGuest.value = true;

    showCustomSnackBar(
      "Welcome, $cleanName! ($guestUsername)",
      title: "Guest Mode Ready",
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> loginWithGoogle(String email, String name, {String? photoUrl}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isEmpty ? cleanEmail.split('@').first : name.trim();

    isSyncing.value = true;

    try {
      final res = await Dio().post(
        "$vpsBaseUrl/google-auth",
        data: {
          "email": cleanEmail,
          "name": cleanName,
          "photoUrl": photoUrl,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (res.statusCode == 200 && res.data is Map && res.data["success"] == true) {
        final userData = res.data["user"];
        final user = PeaceUser.fromJson(Map<String, dynamic>.from(userData)).copyWith(
          photoUrl: photoUrl,
          downloadedSongIds: _getLocalDownloadedSongIds(),
        );

        await _saveUserToRegistry(user);
        await _authBox.put("currentUser", user.toJson());
        currentUser.value = user;
        isLoggedIn.value = true;
        isGuest.value = false;

        // Restore cloud backup from VPS
        if (res.data["cloudData"] is Map) {
          await _restoreCloudData(Map<String, dynamic>.from(res.data["cloudData"]));
        }

        isSyncing.value = false;
        showCustomSnackBar(
          "Signed in as $cleanEmail (${user.username})",
          title: "Google Account Connected 🎉",
          duration: const Duration(seconds: 3),
        );
        return;
      }
    } catch (e) {
      debugPrint("VPS Google Auth error: $e");
    }

    // Local fallback
    final userId = "google_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}";
    final user = PeaceUser(
      userId: userId,
      name: cleanName,
      username: generateUniqueUsername(cleanName),
      email: cleanEmail,
      isGuest: false,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      downloadedSongIds: _getLocalDownloadedSongIds(),
    );
    await _saveUserToRegistry(user);
    await _authBox.put("currentUser", user.toJson());
    currentUser.value = user;
    isLoggedIn.value = true;
    isGuest.value = false;
    isSyncing.value = false;

    showCustomSnackBar(
      "Signed in as $cleanEmail (${user.username})",
      title: "Google Account Connected",
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> linkGuestToGoogle(String email, String name, {String? photoUrl}) async {
    if (currentUser.value == null) return;

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isEmpty ? currentUser.value!.name : name.trim();
    final userId = "google_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}";
    final generatedUsername = generateUniqueUsername(cleanName);

    final updated = currentUser.value!.copyWith(
      userId: userId,
      name: cleanName,
      username: currentUser.value!.username.isNotEmpty && !currentUser.value!.username.contains("guest")
          ? currentUser.value!.username
          : generatedUsername,
      email: cleanEmail,
      isGuest: false,
      photoUrl: photoUrl,
      lastSyncedAt: DateTime.now(),
    );

    await _saveUserToRegistry(updated);
    await _authBox.put("currentUser", updated.toJson());
    currentUser.value = updated;
    isGuest.value = false;

    // Sync all existing guest playlists and favorites to this Google account
    await syncWithCloud(showNotice: false);

    showCustomSnackBar(
      "Guest data successfully linked to $cleanEmail ($generatedUsername)",
      title: "Account Upgraded to Cloud!",
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> syncWithCloud({bool showNotice = true}) async {
    if (currentUser.value == null) return;
    isSyncing.value = true;

    try {
      final user = currentUser.value!;
      final cloudKey = "cloud_sync_${user.userId}";

      // 1. Gather all local favorites (LIBFAV)
      final favBox = await Hive.openBox("LIBFAV");
      final favoritesList = favBox.values.toList();

      // 2. Gather all local user playlists (LibraryPlaylists)
      final playlistBox = await Hive.openBox("LibraryPlaylists");
      final playlistsList = playlistBox.values.toList();

      // 3. Gather recently played (LIBRP)
      final recentBox = await Hive.openBox("LIBRP");
      final recentsList = recentBox.values.toList();

      // 4. Gather downloaded songs metadata
      final downloadsBox = Hive.box("SongDownloads");
      final downloadedSongs = downloadsBox.values.toList();
      final downloadedIds = downloadsBox.keys.map((e) => e.toString()).toList();

      final cloudPayload = {
        'userId': user.userId,
        'email': user.email,
        'name': user.name,
        'syncedAt': DateTime.now().toIso8601String(),
        'favorites': favoritesList,
        'playlists': playlistsList,
        'recentlyPlayed': recentsList,
        'downloadedSongs': downloadedSongs,
        'downloadedSongIds': downloadedIds,
      };

      // Store in cloud storage box (ready for online Firestore / REST sync)
      await _authBox.put(cloudKey, cloudPayload);

      // Upload to VPS Cloud server!
      if (!user.isGuest) {
        try {
          await Dio().post(
            "$vpsBaseUrl/sync",
            data: cloudPayload,
            options: Options(
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {"Content-Type": "application/json"},
            ),
          );
        } catch (e) {
          debugPrint("VPS Cloud Sync upload error: $e");
        }
      }

      final updatedUser = user.copyWith(
        lastSyncedAt: DateTime.now(),
        downloadedSongIds: downloadedIds,
      );
      await _authBox.put("currentUser", updatedUser.toJson());
      currentUser.value = updatedUser;

      if (showNotice) {
        showCustomSnackBar(
          "Favorites, Playlists aur Downloads VPS Cloud par sync ho gaye!",
          title: "Cloud Sync Complete ☁️",
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint("Sync error: $e");
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _restoreCloudData(Map<String, dynamic> cloudData) async {
    try {
      // 1. Restore Favorites
      if (cloudData['favorites'] is List) {
        final favBox = await Hive.openBox("LIBFAV");
        for (var item in cloudData['favorites']) {
          if (item is Map && item.containsKey('id')) {
            await favBox.put(item['id'], item);
          }
        }
      }

      // 2. Restore Playlists
      if (cloudData['playlists'] is List) {
        final playlistBox = await Hive.openBox("LibraryPlaylists");
        for (var item in cloudData['playlists']) {
          if (item is Map && item.containsKey('playlistId')) {
            await playlistBox.put(item['playlistId'], item);
          }
        }
      }

      // 3. Restore Recently Played
      if (cloudData['recentlyPlayed'] is List) {
        final recentBox = await Hive.openBox("LIBRP");
        for (var item in cloudData['recentlyPlayed']) {
          if (item is Map && item.containsKey('id')) {
            await recentBox.put(item['id'], item);
          }
        }
      }

      // 4. Check for offline downloads on this device!
      final cloudDownloadedIds = (cloudData['downloadedSongIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final localDownloadsBox = Hive.box("SongDownloads");
      final missingSongIds = cloudDownloadedIds
          .where((id) => !localDownloadsBox.containsKey(id))
          .toList();

      if (missingSongIds.isNotEmpty && cloudData['downloadedSongs'] is List) {
        final missingSongs = (cloudData['downloadedSongs'] as List)
            .whereType<Map>()
            .where((m) => missingSongIds.contains(m['id']))
            .map<MediaItem?>((m) => MediaItemBuilder.fromJson(m))
            .whereType<MediaItem>()
            .toList();

        if (missingSongs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showDownloadLibraryPrompt(missingSongs);
          });
        }
      }
    } catch (e) {
      debugPrint("Restore error: $e");
    }
  }

  void _showDownloadLibraryPrompt(List<MediaItem> missingSongs) {
    if (Get.context == null) return;

    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE040FB).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_download_rounded,
                      color: Color(0xFFE040FB),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Download Your Offline Library?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Aapke account me ${missingSongs.length} songs pehle se saved the.",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Kya aap inhe is phone me bhi download karna chahte hain? Aap chahein to internet se online bhi stream kar sakte hain.",
                style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        showCustomSnackBar(
                          "Aapke gaane online stream honge.",
                          title: "Online Streaming Active",
                        );
                      },
                      child: const Text("Stream Online"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE040FB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // Trigger batch download
                        try {
                          Get.find<Downloader>().download(null, songList: missingSongs);
                          showCustomSnackBar(
                            "${missingSongs.length} gaano ka download background me shuru ho gaya hai!",
                            title: "Downloading Library 🎵",
                            duration: const Duration(seconds: 3),
                          );
                        } catch (e) {
                          debugPrint("Batch download error: $e");
                        }
                      },
                      child: Text("Download All (${missingSongs.length})"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> logout() async {
    await _authBox.delete("currentUser");
    currentUser.value = null;
    isLoggedIn.value = false;
    isGuest.value = false;

    showCustomSnackBar(
      "Aapka account logout ho gaya hai.",
      title: "Logged Out",
    );
  }

  Future<void> clearGuestData() async {
    await _authBox.delete("currentUser");
    currentUser.value = null;
    isLoggedIn.value = false;
    isGuest.value = false;

    showCustomSnackBar(
      "Guest session hata diya gaya hai.",
      title: "Guest Data Cleared",
    );
  }

  List<String> _getLocalDownloadedSongIds() {
    try {
      if (Hive.isBoxOpen("SongDownloads")) {
        return Hive.box("SongDownloads").keys.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}
