import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoEnterScale;
  late Animation<double> _logoExitScale;
  late Animation<Offset> _labelEnterSlide;
  late Animation<Offset> _labelExitSlide;
  late Animation<double> _labelEnterOpacity;
  late Animation<double> _labelExitOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // 1. Entrance: Logo scales up (0.0 -> 0.35)
    _logoEnterScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // 2. Entrance: Label slides out from logo & fades in (0.25 -> 0.45)
    _labelEnterSlide = Tween<Offset>(
      begin: const Offset(-0.35, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _labelEnterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.45, curve: Curves.easeIn),
      ),
    );

    // 3. Exit: Label slides back inside logo & fades out (0.68 -> 0.85)
    _labelExitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.45, 0.0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    _labelExitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.82, curve: Curves.easeOut),
      ),
    );

    // 4. Exit: Logo scales down / closes (0.83 -> 1.0)
    _logoExitScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.83, 1.0, curve: Curves.easeInOutBack),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Get.off(
          () => const Home(),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 350),
        );
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Compute combined logo scale
            final double currentLogoScale = _controller.value < 0.65
                ? _logoEnterScale.value
                : _logoExitScale.value;

            // Compute combined label slide offset
            final Offset currentLabelSlide = _controller.value < 0.65
                ? _labelEnterSlide.value
                : _labelExitSlide.value;

            // Compute combined label opacity
            final double currentLabelOpacity = (_controller.value < 0.65
                    ? _labelEnterOpacity.value
                    : _labelExitOpacity.value)
                .clamp(0.0, 1.0);

            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo with scale animation (no background box)
                Transform.scale(
                  scale: currentLogoScale,
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Image.asset(
                      'assets/icons/colored-logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Label that slides out to the right and later slides back inside
                Opacity(
                  opacity: currentLabelOpacity,
                  child: SlideTransition(
                    position: AlwaysStoppedAnimation(currentLabelSlide),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Peace Music",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Made by Harsh",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
