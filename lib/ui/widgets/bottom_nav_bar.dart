import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.75),
            Colors.black.withOpacity(0.95),
            Colors.black,
          ],
          stops: const [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomInset > 0 ? bottomInset : 8,
      ),
      child: Container(
        height: 52,
        color: Colors.transparent,
        child: Obx(() {
          final int selectedIndex =
              homeScreenController.tabIndex.toInt().clamp(0, 3);

          return Row(
            children: [
              _buildNavItem(
                index: 0,
                selectedIndex: selectedIndex,
                selectedIcon: Icons.home_rounded,
                unselectedIcon: Icons.home_outlined,
                label: modifyNgetlabel('home'.tr),
                onTap: () =>
                    homeScreenController.onBottonBarTabSelected(0),
              ),
              _buildNavItem(
                index: 1,
                selectedIndex: selectedIndex,
                selectedIcon: Icons.search_rounded,
                unselectedIcon: Icons.search_rounded,
                label: modifyNgetlabel('search'.tr),
                onTap: () =>
                    homeScreenController.onBottonBarTabSelected(1),
              ),
              _buildNavItem(
                index: 2,
                selectedIndex: selectedIndex,
                selectedIcon: Icons.my_library_music_rounded,
                unselectedIcon: Icons.library_music_outlined,
                label: modifyNgetlabel('library'.tr),
                onTap: () =>
                    homeScreenController.onBottonBarTabSelected(2),
              ),
              _buildNavItem(
                index: 3,
                selectedIndex: selectedIndex,
                selectedIcon: Icons.tune_rounded,
                unselectedIcon: Icons.settings_outlined,
                label: modifyNgetlabel('settings'.tr),
                onTap: () =>
                    homeScreenController.onBottonBarTabSelected(3),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int selectedIndex,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool isSelected = selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 0.95,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    isSelected ? selectedIcon : unselectedIcon,
                    size: 24,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.50),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.45),
                    letterSpacing: 0.2,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String modifyNgetlabel(String label) {
    if (label.length > 9) {
      return "${label.substring(0, 8)}..";
    }
    return label;
  }
}
