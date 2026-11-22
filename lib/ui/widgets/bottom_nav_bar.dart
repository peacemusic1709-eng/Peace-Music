import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    return Obx(
      () => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor.withOpacity(0.75),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.6,
                ),
              ),
            ),
            child: NavigationBar(
              elevation: 0,
              height: 65,
              onDestinationSelected: homeScreenController.onBottonBarTabSelected,
              selectedIndex: homeScreenController.tabIndex.toInt(),
              backgroundColor: Colors.transparent,
              indicatorColor: Theme.of(context).colorScheme.secondary.withOpacity(0.22),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  selectedIcon: const Icon(Icons.home_rounded, size: 27),
                  icon: const Icon(Icons.home_outlined, size: 24),
                  label: modifyNgetlabel('home'.tr),
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.search_rounded, size: 27),
                  icon: const Icon(Icons.search_rounded, size: 24),
                  label: modifyNgetlabel('search'.tr),
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.my_library_music_rounded, size: 27),
                  icon: const Icon(Icons.library_music_outlined, size: 24),
                  label: modifyNgetlabel('library'.tr),
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.tune_rounded, size: 27),
                  icon: const Icon(Icons.settings_outlined, size: 24),
                  label: modifyNgetlabel('settings'.tr),
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
