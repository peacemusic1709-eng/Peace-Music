import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomInset > 0 ? bottomInset : 10,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), // Thoda kam round, sleek modern rectangle
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
          child: Container(
            height: 54, // Vertically chota (54 instead of 66)
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08), // Colorless pure frosted glass, NO black!
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Obx(() {
              final int selectedIndex =
                  homeScreenController.tabIndex.toInt().clamp(0, 3);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final double tabWidth = constraints.maxWidth / 4;

                  return Stack(
                    children: [
                      // Smooth sliding active layer - Pure Colorless Glass Sheen, NO purple!
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: selectedIndex * tabWidth + 4,
                        top: 4,
                        bottom: 4,
                        width: tabWidth - 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18), // Colorless glass highlight
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.06),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tabs
                      Row(
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
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        ),
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
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.05 : 0.95,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    isSelected ? selectedIcon : unselectedIcon,
                    size: 21,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.50),
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
