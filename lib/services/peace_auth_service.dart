import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  Box get _authBox => Hive.box("PeaceAuth");

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

  Future<void> loginAsGuest(String fullName) async {
    final cleanName = fullName.trim().isEmpty ? "Guest User" : fullName.trim();
    final guestId = "guest_${DateTime.now().millisecondsSinceEpoch}";

    // Capture currently downloaded songs
    final currentDownloads = _getLocalDownloadedSongIds();

    final user = PeaceUser(
      userId: guestId,
      name: cleanName,
      email: "",
      isGuest: true,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      downloadedSongIds: currentDownloads,
    );

    await _authBox.put("currentUser", user.toJson());
    currentUser.value = user;
    isLoggedIn.value = true;
    isGuest.value = true;

    showCustomSnackBar(
      "Welcome, $cleanName!",
      title: "Guest Account Created",
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> loginWithGoogle(String email, String name, {String? photoUrl}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isEmpty ? cleanEmail.split('@').first : name.trim();
    final userId = "google_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}";

    isSyncing.value = true;

    // Check if cloud backup exists in cloud storage or local cloud mock
    final cloudKey = "cloud_sync_$userId";
    Map<String, dynamic>? cloudBackup;
    if (_authBox.containsKey(cloudKey)) {
      try {
        final raw = _authBox.get(cloudKey);
        if (raw is Map) cloudBackup = Map<String, dynamic>.from(raw);
      } catch (_) {}
    }

    final currentDownloads = _getLocalDownloadedSongIds();
    final user = PeaceUser(
      userId: userId,
      name: cleanName,
      email: cleanEmail,
      isGuest: false,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      downloadedSongIds: currentDownloads,
    );

    await _authBox.put("currentUser", user.toJson());
    currentUser.value = user;
    isLoggedIn.value = true;
    isGuest.value = false;

    // If cloud backup exists, restore it and check for missing downloads
    if (cloudBackup != null) {
      await _restoreCloudData(cloudBackup);
    } else {
      // First time login on this email: save initial cloud backup
      await syncWithCloud(showNotice: false);
    }

    isSyncing.value = false;

    showCustomSnackBar(
      "Signed in as $cleanEmail",
      title: "Google Account Connected",
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> linkGuestToGoogle(String email, String name, {String? photoUrl}) async {
    if (currentUser.value == null) return;

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isEmpty ? currentUser.value!.name : name.trim();
    final userId = "google_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}";

    final updated = currentUser.value!.copyWith(
      userId: userId,
      name: cleanName,
      email: cleanEmail,
      isGuest: false,
      photoUrl: photoUrl,
      lastSyncedAt: DateTime.now(),
    );

    await _authBox.put("currentUser", updated.toJson());
    currentUser.value = updated;
    isGuest.value = false;

    // Sync all existing guest playlists and favorites to this Google account
    await syncWithCloud(showNotice: false);

    showCustomSnackBar(
      "Guest data successfully linked to $cleanEmail",
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

      final updatedUser = user.copyWith(
        lastSyncedAt: DateTime.now(),
        downloadedSongIds: downloadedIds,
      );
      await _authBox.put("currentUser", updatedUser.toJson());
      currentUser.value = updatedUser;

      if (showNotice) {
        showCustomSnackBar(
          "Favorites, Playlists aur Downloads sync ho gaye hain!",
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
