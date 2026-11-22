import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/peace_auth_service.dart';
import 'peace_auth_dialogs.dart';

class PeaceProfileCard extends StatelessWidget {
  const PeaceProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<PeaceAuthService>();

    return Obx(() {
      final user = authService.currentUser.value;
      final isSyncing = authService.isSyncing.value;

      if (user == null || !authService.isLoggedIn.value) {
        // Not logged in card
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE040FB).withOpacity(0.18),
                const Color(0xFF2196F3).withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_circle_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Welcome to Peace Music",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Sign in to sync your playlists & offline songs across phones",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE040FB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        PeaceOnboardingBottomSheet.show(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.login_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text("Log In / Sign Up", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const PeaceGuestDialog(),
                        );
                      },
                      child: const Text("Guest Mode"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      // Logged in as Guest
      if (user.isGuest) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE040FB).withOpacity(0.2),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : "G",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE040FB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                "GUEST",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orangeAccent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${user.username.isNotEmpty ? '${user.username} • ' : ''}Guest Profile (Local)",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                    tooltip: "Clear Guest Data",
                    onPressed: () {
                      _showLogoutConfirmDialog(context, isGuest: true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Upgrade banner to link with Google
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE040FB).withOpacity(0.2),
                      const Color(0xFF2196F3).withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_sync_rounded, color: Color(0xFFE040FB), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Multi-device cloud backup ke liye Gmail link karein",
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final auth = Get.find<PeaceAuthService>();
                        final success = await auth.triggerGoogleDeviceSignIn();
                        if (!success && auth.currentUser.value?.isGuest == true) {
                          showDialog(
                            context: context,
                            builder: (ctx) => const GoogleLoginDialog(),
                          );
                        }
                      },
                      child: const Text(
                        "Link Gmail",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Logged in with Google Account
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2196F3).withOpacity(0.2),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "SYNCED ☁️",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${user.username.isNotEmpty ? '${user.username} • ' : ''}${user.email}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, color: Colors.white70),
                  tooltip: "Sync with Cloud",
                  onPressed: isSyncing
                      ? null
                      : () {
                          authService.syncWithCloud();
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white38, size: 20),
                  tooltip: "Logout",
                  onPressed: () {
                    _showLogoutConfirmDialog(context, isGuest: false);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void _showLogoutConfirmDialog(BuildContext context, {required bool isGuest}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isGuest ? "Clear Guest Session?" : "Log Out?"),
        content: Text(
          isGuest
              ? "Aapka guest account remove ho jayega. Kya aap continue karna chahte hain?"
              : "Aap account se logout ho jayenge. Aapke playlists cloud me safe rahenge.",
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (isGuest) {
                Get.find<PeaceAuthService>().clearGuestData();
              } else {
                Get.find<PeaceAuthService>().logout();
              }
            },
            child: Text(isGuest ? "Clear Data" : "Log Out"),
          ),
        ],
      ),
    );
  }
}
