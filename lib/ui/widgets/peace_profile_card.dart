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
        // Not logged in card - Modern Dark Minimalist
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF14141B),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFFA29BFE),
                      size: 26,
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
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "Sign in to sync your playlists & favorite songs",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8F90A6),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        onPressed: () {
                          PeaceOnboardingBottomSheet.show(context);
                        },
                        child: const Text(
                          "Log In / Sign Up",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      onPressed: () {
                        authService.loginAsGuest("Guest User");
                      },
                      child: const Text(
                        "Guest Mode",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      // Logged In (Guest or Registered User)
      final isGuest = user.isGuest;
      final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : "P";

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
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
                // Modern Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF8E44AD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name and Handle/Email
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
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isGuest
                                  ? Colors.orange.withOpacity(0.15)
                                  : const Color(0xFF6C5CE7).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isGuest
                                    ? Colors.orange.withOpacity(0.3)
                                    : const Color(0xFF6C5CE7).withOpacity(0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isGuest ? "GUEST" : "ACTIVE",
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isGuest ? Colors.orangeAccent : const Color(0xFFA29BFE),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isGuest
                            ? "Guest Session (Saved on device)"
                            : (user.email.isNotEmpty ? user.email : user.username),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF8F90A6),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Action Icons (Sync & Logout)
                if (!isGuest)
                  IconButton(
                    icon: isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA29BFE)),
                          )
                        : const Icon(Icons.sync_rounded, color: Colors.white70, size: 22),
                    tooltip: "Sync with Cloud",
                    onPressed: isSyncing ? null : () => authService.syncWithCloud(),
                  ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white38, size: 20),
                  tooltip: "Logout",
                  onPressed: () => _showLogoutConfirmDialog(context, isGuest: isGuest),
                ),
              ],
            ),

            if (isGuest) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_outlined, color: Color(0xFFA29BFE), size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Cloud backup aur multi-phone sync ke liye login karein",
                        style: TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => PeaceOnboardingBottomSheet.show(context),
                      child: const Text(
                        "Connect",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  void _showLogoutConfirmDialog(BuildContext context, {required bool isGuest}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
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
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Get.find<PeaceAuthService>().logout();
            },
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
