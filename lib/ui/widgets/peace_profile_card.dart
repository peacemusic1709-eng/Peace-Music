import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/peace_auth_service.dart';
import '../screens/Settings/components/custom_expansion_tile.dart';
import 'peace_auth_dialogs.dart';

class PeaceProfileCard extends StatelessWidget {
  const PeaceProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<PeaceAuthService>();

    return Obx(() {
      final user = authService.currentUser.value;
      final isSyncing = authService.isSyncing.value;
      final isLoggedIn = authService.isLoggedIn.value && user != null;

      if (!isLoggedIn) {
        return CustomExpansionTile(
          icon: Icons.person_outline_rounded,
          title: "Account Info",
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.login_rounded, color: Color(0xFF7C4DFF), size: 20),
              ),
              title: const Text(
                "Log In / Sign Up",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                "Access millions of songs and sync playlists across devices",
                style: TextStyle(fontSize: 12.5, color: Colors.white60),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white54),
              onTap: () => PeaceOnboardingBottomSheet.show(context),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_circle_outlined, color: Colors.white70, size: 20),
              ),
              title: const Text(
                "Continue as Guest",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                "Use local profile without cloud account",
                style: TextStyle(fontSize: 12.5, color: Colors.white60),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white54),
              onTap: () => authService.loginAsGuest("Guest User"),
            ),
          ],
        );
      }

      final isGuest = user.isGuest;
      final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : "P";

      return CustomExpansionTile(
        icon: Icons.person_rounded,
        title: "Account Info",
        children: [
          // 1. User Profile Detail Tile
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              isGuest
                  ? "Guest Session (Saved on device)"
                  : (user.email.isNotEmpty ? user.email : user.username),
              style: const TextStyle(fontSize: 12.5, color: Colors.white60),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isGuest
                    ? Colors.orange.withOpacity(0.18)
                    : const Color(0xFF7C4DFF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isGuest
                      ? Colors.orangeAccent.withOpacity(0.4)
                      : const Color(0xFF7C4DFF).withOpacity(0.5),
                ),
              ),
              child: Text(
                isGuest ? "GUEST" : "ACTIVE",
                style: TextStyle(
                  color: isGuest ? Colors.orangeAccent : const Color(0xFFB388FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // 2. Cloud Sync or Upgrade Account
          if (isGuest)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              leading: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF7C4DFF)),
              title: const Text("Connect Account", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Log in or sign up for multi-phone cloud backup", style: TextStyle(fontSize: 12, color: Colors.white60)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white54),
              onTap: () => PeaceOnboardingBottomSheet.show(context),
            )
          else
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF7C4DFF)),
              title: const Text("Cloud Sync", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Sync playlists, favorites & history", style: TextStyle(fontSize: 12, color: Colors.white60)),
              trailing: isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: "Sync with Cloud",
                      onPressed: () => authService.syncWithCloud(),
                    ),
            ),

          const Divider(height: 16, color: Colors.white12),

          // 3. Logout (Niche ekdm logout)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFFF5252)),
            title: const Text(
              "Log Out",
              style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              isGuest
                  ? "Log out from guest session"
                  : "Sign out of your Peace Music account",
              style: TextStyle(color: const Color(0xFFFF5252).withOpacity(0.7), fontSize: 12),
            ),
            onTap: () => _showLogoutConfirmDialog(context, isGuest: isGuest),
          ),
        ],
      );
    });
  }

  void _showLogoutConfirmDialog(BuildContext context, {required bool isGuest}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141520),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          isGuest ? "Log out from Guest?" : "Log Out?",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          isGuest
              ? "Aapka guest session logout ho jayega. Lekin aapka data phone par safe rahega aur aage guest select karne par wapas aa jayega."
              : "Aap account se logout ho jayenge. Aapke playlists cloud me safe rahenge.",
          style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Get.find<PeaceAuthService>().logout();
              PeaceOnboardingBottomSheet.show(context);
            },
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
