import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../services/peace_auth_service.dart';

enum OnboardingView {
  welcome,
  signUpEmail,
  signUpPassword,
  signUpName,
  loginEmail,
  otpVerify,
}

/// Official Vector 4-Color Google 'G' Logo
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final strokeWidth = w * 0.22;
    final radius = (w - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Top arc: Red
    canvas.drawArc(rect, -2.4, 1.6, false, redPaint);
    // Left-bottom arc: Yellow
    canvas.drawArc(rect, 2.3, 1.5, false, yellowPaint);
    // Bottom arc: Green
    canvas.drawArc(rect, 0.75, 1.55, false, greenPaint);
    // Right arc: Blue
    canvas.drawArc(rect, -0.8, 1.55, false, bluePaint);

    // Center horizontal bar for G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(w * 0.44, h * 0.38, w * 0.52, strokeWidth);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(strokeWidth / 4)),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// App Launch First-Time / Guest Onboarding Sheet with Full-Screen Spotify-Tier Flow
class PeaceOnboardingBottomSheet extends StatefulWidget {
  const PeaceOnboardingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PeaceOnboardingBottomSheet(),
    );
  }

  @override
  State<PeaceOnboardingBottomSheet> createState() =>
      _PeaceOnboardingBottomSheetState();
}

class _PeaceOnboardingBottomSheetState
    extends State<PeaceOnboardingBottomSheet> {
  OnboardingView _currentView = OnboardingView.welcome;

  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpNameController = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureLoginPassword = true;
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _isSignUpVerification = false;
  String _targetEmail = "";

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideoBackground();
  }

  void _initVideoBackground() {
    try {
      _videoController = VideoPlayerController.asset("assets/videos/welcome_video.mp4")
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController?.setLooping(true);
            _videoController?.setVolume(0.0);
            _videoController?.play();
          }
        }).catchError((e) {
          debugPrint("Video initialization error: $e");
        });
    } catch (e) {
      debugPrint("Video asset load error: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpNameController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _goTo(OnboardingView view) {
    setState(() {
      _currentView = view;
    });
    if (_videoController != null && _isVideoInitialized) {
      if (view == OnboardingView.welcome) {
        _videoController?.play();
      } else {
        _videoController?.pause();
      }
    }
  }

  Future<void> _performFastOtpVerify(String otp) async {
    final auth = Get.find<PeaceAuthService>();
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    try {
      if (_isSignUpVerification) {
        final valid = auth.verifyOtp(_targetEmail, otp);
        if (valid) {
          auth.showCustomSnackBar(
            "Account verify ho gaya! Welcome to Peace Music.",
            title: "Sign Up Verified 🎉",
            duration: const Duration(seconds: 4),
          );
          if (mounted) Navigator.pop(context);
        } else {
          auth.showCustomSnackBar(
            "Galat OTP code! Kripya check karein.",
            title: "Invalid Code",
          );
          setState(() => _isVerifying = false);
        }
      } else {
        final success = await auth.loginWithEmailOtp(
          email: _targetEmail,
          enteredOtp: otp,
        );
        if (success) {
          if (mounted) Navigator.pop(context);
        } else {
          setState(() => _isVerifying = false);
        }
      }
    } catch (e) {
      debugPrint("OTP verification error: $e");
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = Get.find<PeaceAuthService>();
    setState(() => _isLoading = true);

    bool loggedIn = false;
    try {
      loggedIn = await auth.triggerGoogleDeviceSignIn();
    } catch (e) {
      debugPrint("Native Google Sign In exception: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (loggedIn && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top > 0 ? mq.padding.top : 24.0;
    return WillPopScope(
      onWillPop: () async {
        if (_currentView == OnboardingView.welcome) {
          // Mandatory choice on first open
          return false;
        } else if (_currentView == OnboardingView.signUpPassword) {
          _goTo(OnboardingView.signUpEmail);
          return false;
        } else if (_currentView == OnboardingView.signUpName) {
          _goTo(OnboardingView.signUpPassword);
          return false;
        } else if (_currentView == OnboardingView.otpVerify) {
          _goTo(_isSignUpVerification
              ? OnboardingView.signUpName
              : OnboardingView.loginEmail);
          return false;
        } else {
          _goTo(OnboardingView.welcome);
          return false;
        }
      },
      child: Container(
        height: mq.size.height,
        width: mq.size.width,
        color: const Color(0xFF090A10),
        child: Stack(
          children: [
            // Video Background (Visible on Welcome page)
            if (_currentView == OnboardingView.welcome &&
                _videoController != null &&
                _isVideoInitialized &&
                _videoController!.value.isInitialized)
              Positioned.fill(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
              ),

            // Subtle dark overlay gradient for readability
            if (_currentView == OnboardingView.welcome && _isVideoInitialized)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.40),
                        Colors.black.withOpacity(0.60),
                        const Color(0xFF090A10).withOpacity(0.92),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, topInset + 12, 24, 24),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: mq.size.height - mq.padding.top - mq.padding.bottom - 48,
                    ),
                    child: IntrinsicHeight(
                      child: _buildCurrentView(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(BuildContext context) {
    switch (_currentView) {
      case OnboardingView.welcome:
        return _buildWelcomeView(context);
      case OnboardingView.signUpEmail:
        return _buildSignUpEmailView(context);
      case OnboardingView.signUpPassword:
        return _buildSignUpPasswordView(context);
      case OnboardingView.signUpName:
        return _buildSignUpNameView(context);
      case OnboardingView.loginEmail:
        return _buildLoginEmailView(context);
      case OnboardingView.otpVerify:
        return _buildOtpVerifyView(context);
    }
  }

  // 1. WELCOME SCREEN (Mandatory selection, no close button)
  Widget _buildWelcomeView(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Spacer(),

        // Brand Logo with Luxury Violet Glow
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.38),
                  blurRadius: 48,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Image.asset(
              'assets/icons/colored-logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Tagline
        const Text(
          "Millions of songs.\nFree on Peace.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.8,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Lossless Audio Streaming • Made with ❤️ by Harsh",
          style: TextStyle(
            fontSize: 13,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),

        const Spacer(),

        // Button 1: Sign up for free
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: const Color(0xFF7C4DFF).withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: () => _goTo(OnboardingView.signUpEmail),
            child: const Text(
              "Sign up for free",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Button 2: Log in
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF13141F),
              side: const BorderSide(color: Color(0xFF2C2E42), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: () => _goTo(OnboardingView.loginEmail),
            child: const Text(
              "Log in",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Continue as Guest (Recovers or creates saved guest profile)
        TextButton(
          onPressed: () async {
            final auth = Get.find<PeaceAuthService>();
            await auth.loginAsGuest("Guest User");
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text(
            "Continue as Guest",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white30,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 2. SIGN UP: STEP 1 (EMAIL)
  Widget _buildSignUpEmailView(BuildContext context) {
    final auth = Get.find<PeaceAuthService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            InkWell(
              onTap: () => _goTo(OnboardingView.welcome),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Create account",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),

        const Text(
          "What's your email address?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "You'll need to confirm this email later.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 28),

        const Text(
          "Email",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _signUpEmailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: const Color(0xFF7C4DFF),
          decoration: InputDecoration(
            hintText: "Enter your email",
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFF13141F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF7C4DFF).withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: () async {
              final email = _signUpEmailController.text.trim().toLowerCase();
              if (!auth.isValidEmail(email)) {
                auth.showCustomSnackBar(
                  "Kripya valid email address enter karein.",
                  title: "Invalid Email",
                );
                return;
              }

              final isRegistered = await auth.isEmailRegistered(email);
              if (!context.mounted) return;

              if (isRegistered) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF141520),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.white12),
                    ),
                    title: const Text(
                      "This email is already connected to an account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      "Do you want to log in instead?",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Close",
                          style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _loginEmailController.text = email;
                          _goTo(OnboardingView.loginEmail);
                        },
                        child: const Text(
                          "Go to Login",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
                return;
              }

              final defaultName = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').trim();
              if (defaultName.isNotEmpty) {
                _signUpNameController.text = defaultName[0].toUpperCase() + defaultName.substring(1);
              }

              _goTo(OnboardingView.signUpPassword);
            },
            child: const Text(
              "Continue",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 28),

        Row(
          children: const [
            Expanded(child: Divider(color: Colors.white24, thickness: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                "or sign up with",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            Expanded(child: Divider(color: Colors.white24, thickness: 1)),
          ],
        ),
        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF13141F),
              side: const BorderSide(color: Color(0xFF2C2E42), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => _handleGoogleSignIn(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                GoogleLogoWidget(size: 22),
                SizedBox(width: 12),
                Text(
                  "Google",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. SIGN UP: STEP 2 (PASSWORD)
  Widget _buildSignUpPasswordView(BuildContext context) {
    final auth = Get.find<PeaceAuthService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            InkWell(
              onTap: () => _goTo(OnboardingView.signUpEmail),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Create account",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),

        const Text(
          "Create a password",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Use at least 6 characters.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 28),

        const Text(
          "Password",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _signUpPasswordController,
          autofocus: true,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: const Color(0xFF7C4DFF),
          decoration: InputDecoration(
            hintText: "Enter your password",
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFF13141F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white60,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF7C4DFF).withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: () {
              final pwd = _signUpPasswordController.text;
              if (pwd.length < 6) {
                auth.showCustomSnackBar(
                  "Password kam se kam 6 characters ka hona chahiye.",
                  title: "Weak Password",
                );
                return;
              }
              _goTo(OnboardingView.signUpName);
            },
            child: const Text(
              "Continue",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // 4. SIGN UP: STEP 3 (NAME & TERMS)
  Widget _buildSignUpNameView(BuildContext context) {
    final auth = Get.find<PeaceAuthService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            InkWell(
              onTap: () => _goTo(OnboardingView.signUpPassword),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Create account",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),

        const Text(
          "What's your name?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "This appears on your Peace profile.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 28),

        const Text(
          "Name",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _signUpNameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: const Color(0xFF7C4DFF),
          decoration: InputDecoration(
            hintText: "Your name",
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFF13141F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          "By tapping Create account, you agree to Peace Music's Terms of Service and Privacy Policy.",
          style: TextStyle(
            fontSize: 12,
            color: Colors.white60,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF7C4DFF).withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: _isLoading
                ? null
                : () async {
                    final email = _signUpEmailController.text.trim().toLowerCase();
                    final password = _signUpPasswordController.text;
                    final name = _signUpNameController.text.trim().isEmpty
                        ? "Peace User"
                        : _signUpNameController.text.trim();
                    final username = auth.generateUniqueUsername(name);

                    setState(() => _isLoading = true);
                    final registered = await auth.registerUser(
                      name: name,
                      email: email,
                      username: username,
                      password: password,
                    );
                    setState(() => _isLoading = false);

                    if (registered) {
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Create account",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // 5. LOG IN FLOW
  Widget _buildLoginEmailView(BuildContext context) {
    final auth = Get.find<PeaceAuthService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            InkWell(
              onTap: () => _goTo(OnboardingView.welcome),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Log in",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),

        const Text(
          "Log in to Peace",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Welcome back! Enter your details to continue.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 28),

        const Text(
          "Email or Username",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: const Color(0xFF7C4DFF),
          decoration: InputDecoration(
            hintText: "Enter your email or username",
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFF13141F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          "Password",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: const Color(0xFF7C4DFF),
          decoration: InputDecoration(
            hintText: "Enter your password",
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFF13141F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white60,
              ),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => PeaceForgotPasswordDialog.show(context),
            child: const Text(
              "Forgot password?",
              style: TextStyle(
                color: Color(0xFF7C4DFF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF7C4DFF).withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: _isLoading
                ? null
                : () async {
                    final identifier = _loginEmailController.text.trim();
                    final password = _loginPasswordController.text;
                    if (identifier.isEmpty || password.isEmpty) {
                      auth.showCustomSnackBar(
                        "Kripya Email/Username aur Password dono enter karein.",
                        title: "Required Fields",
                      );
                      return;
                    }

                    setState(() => _isLoading = true);
                    final success = await auth.loginWithCredentials(
                      identifier: identifier,
                      password: password,
                    );
                    setState(() => _isLoading = false);

                    if (success && mounted) {
                      Navigator.pop(context);
                    }
                  },
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Log in",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: const [
            Expanded(child: Divider(color: Colors.white24, thickness: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                "or log in with",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            Expanded(child: Divider(color: Colors.white24, thickness: 1)),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF13141F),
              side: const BorderSide(color: Color(0xFF2C2E42), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => _handleGoogleSignIn(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                GoogleLogoWidget(size: 22),
                SizedBox(width: 12),
                Text(
                  "Continue with Google",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              InkWell(
                onTap: () => _goTo(OnboardingView.signUpEmail),
                child: const Text(
                  "Sign up",
                  style: TextStyle(
                    color: Color(0xFF7C4DFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 6. FAST OTP VERIFICATION
  Widget _buildOtpVerifyView(BuildContext context) {
    final auth = Get.find<PeaceAuthService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            InkWell(
              onTap: () => _goTo(_isSignUpVerification
                  ? OnboardingView.signUpName
                  : OnboardingView.loginEmail),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Verify Code",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        const Text(
          "Enter your 6-digit code",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We sent a 6-digit code to $_targetEmail.\nCheck your inbox or Spam folder.",
          style: const TextStyle(
            fontSize: 13.5,
            color: Colors.white60,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        TextField(
          controller: _otpController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 14,
          ),
          maxLength: 6,
          cursorColor: const Color(0xFF7C4DFF),
          decoration: InputDecoration(
            counterText: "",
            hintText: "••••••",
            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 14),
            filled: true,
            fillColor: const Color(0xFF13141F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF242638)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.8),
            ),
          ),
          onChanged: (val) {
            if (val.trim().length == 6) {
              _performFastOtpVerify(val.trim());
            }
          },
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF7C4DFF).withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: _isVerifying
                ? null
                : () => _performFastOtpVerify(_otpController.text.trim()),
            child: _isVerifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Verify & Continue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 22),

        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Didn't receive code? ",
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              InkWell(
                onTap: () async {
                  await auth.sendOtpToEmail(
                    _targetEmail,
                    purpose: _isSignUpVerification ? "Sign Up Verification" : "Login",
                  );
                },
                child: const Text(
                  "Resend Code",
                  style: TextStyle(
                    color: Color(0xFF7C4DFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Login Dialog (Identifier + Password + Forgot Password)
class PeaceLoginDialog extends StatefulWidget {
  const PeaceLoginDialog({super.key});

  @override
  State<PeaceLoginDialog> createState() => _PeaceLoginDialogState();
}

class _PeaceLoginDialogState extends State<PeaceLoginDialog> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _idController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      Get.find<PeaceAuthService>().showCustomSnackBar(
        "Kripya Username/Gmail aur Password dono dalein.",
        title: "Required Fields",
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await Get.find<PeaceAuthService>().loginWithCredentials(
      identifier: identifier,
      password: password,
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE040FB).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.login_rounded, color: Color(0xFFE040FB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Log In",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Apna Unique Username (@username) ya Gmail dalein:",
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 18),

              // Username / Gmail Input
              TextField(
                controller: _idController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Username (@harsh_123) ya Gmail",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Password",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => const PeaceForgotPasswordDialog(),
                    );
                  },
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Color(0xFFE040FB),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE040FB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Log In",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Switch to Sign Up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Naya account banana hai? ", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (ctx) => const PeaceSignUpDialog(),
                      );
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign Up Dialog with Live Auto-Generated Unique Username
class PeaceSignUpDialog extends StatefulWidget {
  const PeaceSignUpDialog({super.key});

  @override
  State<PeaceSignUpDialog> createState() => _PeaceSignUpDialogState();
}

class _PeaceSignUpDialogState extends State<PeaceSignUpDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      final name = _nameController.text.trim();
      if (name.isNotEmpty && _usernameController.text.isEmpty) {
        _usernameController.text = Get.find<PeaceAuthService>().generateUniqueUsername(name);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleProceedToOtp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final auth = Get.find<PeaceAuthService>();

    if (name.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty) {
      auth.showCustomSnackBar("Kripya sabhi details bharein.", title: "Missing Information");
      return;
    }

    if (!auth.isValidEmail(email)) {
      auth.showCustomSnackBar("Kripya valid Gmail address dalein (@gmail.com).", title: "Invalid Gmail");
      return;
    }

    if (password.length < 4) {
      auth.showCustomSnackBar("Password kam se kam 4 characters ka hona chahiye.", title: "Weak Password");
      return;
    }

    if (password != confirmPassword) {
      auth.showCustomSnackBar("Dono password match nahi ho rahe!", title: "Password Mismatch");
      return;
    }

    setState(() => _isLoading = true);
    await auth.sendOtpToEmail(email, purpose: "Sign Up Verification");
    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => PeaceOtpVerificationDialog(
          email: email,
          name: name,
          username: username,
          password: password,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE040FB).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Color(0xFFE040FB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Full Name
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Aapka Pura Naam (Full Name)",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Gmail Address
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Gmail Address (e.g. name@gmail.com)",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Unique Username (Auto suggested)
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Unique Username (@username)",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFFE040FB), size: 20),
                  suffixIcon: IconButton(
                    tooltip: "Generate New Username",
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
                    onPressed: () {
                      final name = _nameController.text.trim();
                      _usernameController.text = Get.find<PeaceAuthService>().generateUniqueUsername(name);
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFFE040FB).withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Yeh aapka unique handle hoga jisse aap directly login kar sakenge.",
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 12),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Password",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Confirm Password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Confirm Password",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_clock_outlined, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 22),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE040FB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleProceedToOtp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.mark_email_read_outlined, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Verify Gmail via OTP",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// OTP Verification Dialog
class PeaceOtpVerificationDialog extends StatefulWidget {
  final String email;
  final String name;
  final String username;
  final String password;

  const PeaceOtpVerificationDialog({
    super.key,
    required this.email,
    required this.name,
    required this.username,
    required this.password,
  });

  @override
  State<PeaceOtpVerificationDialog> createState() => _PeaceOtpVerificationDialogState();
}

class _PeaceOtpVerificationDialogState extends State<PeaceOtpVerificationDialog> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final enteredOtp = _otpController.text.trim();
    final auth = Get.find<PeaceAuthService>();

    if (enteredOtp.length < 4) {
      auth.showCustomSnackBar("Kripya 6-digit OTP code dalein.", title: "Invalid Code");
      return;
    }

    setState(() => _isLoading = true);
    final isValid = auth.verifyOtp(widget.email, enteredOtp);

    if (!isValid) {
      setState(() => _isLoading = false);
      auth.showCustomSnackBar("Galat OTP code! Kripya check karein.", title: "Verification Failed");
      return;
    }

    // Complete registration
    final registered = await auth.registerUser(
      name: widget.name,
      email: widget.email,
      username: widget.username,
      password: widget.password,
    );

    setState(() => _isLoading = false);

    if (registered && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE040FB).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFFE040FB), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "Verify Gmail Address",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Humne aapke Gmail (${widget.email}) par 6-digit verification code bheja hai:",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Instant OTP Auto-Fill Card
            Builder(builder: (ctx) {
              final activeOtp = Get.find<PeaceAuthService>().getOtpForEmail(widget.email) ?? "";
              if (activeOtp.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE040FB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Your OTP Code:", style: TextStyle(fontSize: 11, color: Colors.white60)),
                        Text(activeOtp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE040FB), letterSpacing: 2)),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.amberAccent),
                      label: const Text("Auto-Fill", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _otpController.text = activeOtp;
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

            // OTP Input
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: "",
                hintText: "• • • • • •",
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Resend OTP
            TextButton(
              onPressed: () {
                Get.find<PeaceAuthService>().sendOtpToEmail(widget.email, purpose: "Resent");
              },
              child: const Text("Resend OTP Code", style: TextStyle(color: Color(0xFFE040FB), fontSize: 13)),
            ),
            const SizedBox(height: 16),

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE040FB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _handleVerify,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Verify & Create Account",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Forgot Password Dialog (OTP + New Password Reset)
class PeaceForgotPasswordDialog extends StatefulWidget {
  const PeaceForgotPasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const PeaceForgotPasswordDialog(),
    );
  }

  @override
  State<PeaceForgotPasswordDialog> createState() => _PeaceForgotPasswordDialogState();
}

class _PeaceForgotPasswordDialogState extends State<PeaceForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final auth = Get.find<PeaceAuthService>();

    if (!auth.isValidEmail(email)) {
      auth.showCustomSnackBar("Kripya valid Gmail address dalein.", title: "Invalid Gmail");
      return;
    }

    setState(() => _isLoading = true);
    final exists = await auth.isEmailRegistered(email);
    if (!exists) {
      setState(() => _isLoading = false);
      auth.showCustomSnackBar("Yeh Gmail kisi account se juda nahi hai! Pehle Sign Up karein.", title: "Email Not Found");
      return;
    }

    await auth.sendOtpToEmail(email, purpose: "Password Reset");
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    final enteredOtp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;
    final auth = Get.find<PeaceAuthService>();

    if (enteredOtp.length < 4 || newPassword.length < 4) {
      auth.showCustomSnackBar("OTP aur kam se kam 4 character ka naya password dalein.", title: "Incomplete Form");
      return;
    }

    setState(() => _isLoading = true);
    final isValid = auth.verifyOtp(email, enteredOtp);

    if (!isValid) {
      setState(() => _isLoading = false);
      auth.showCustomSnackBar("Galat OTP code! Kripya check karein.", title: "Invalid OTP");
      return;
    }

    final success = await auth.resetPassword(email: email, newPassword: newPassword);
    if (success) {
      // Auto login with new password
      await auth.loginWithCredentials(identifier: email, password: newPassword);
      if (mounted) Navigator.pop(context);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock_reset_rounded, color: Color(0xFFE040FB), size: 26),
                      SizedBox(width: 10),
                      Text(
                        "Reset Password",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                !_otpSent
                    ? "Apna registered Gmail dalein. Hum password reset code bhejenge:"
                    : "Gmail par aaya 6-digit OTP code aur naya password dalein:",
                style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 18),

              if (!_otpSent) ...[
                // Gmail Input
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Registered Gmail Address",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE040FB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _handleSendOtp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("Send Reset Code", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                // Instant Reset OTP Auto-Fill Card
                Builder(builder: (ctx) {
                  final activeOtp = Get.find<PeaceAuthService>().getOtpForEmail(_emailController.text) ?? "";
                  if (activeOtp.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE040FB).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Reset OTP Code:", style: TextStyle(fontSize: 11, color: Colors.white60)),
                            Text(activeOtp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE040FB), letterSpacing: 2)),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.amberAccent),
                          label: const Text("Auto-Fill", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            setState(() {
                              _otpController.text = activeOtp;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),

                // OTP Input
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "• • • • • •",
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // New Password Input
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Naya Password",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE040FB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _handleResetPassword,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("Reset Password & Login", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Guest Login Dialog (Full Name prompt)
class PeaceGuestDialog extends StatefulWidget {
  const PeaceGuestDialog({super.key});

  @override
  State<PeaceGuestDialog> createState() => _PeaceGuestDialogState();
}

class _PeaceGuestDialogState extends State<PeaceGuestDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Guest Mode",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Guest bankar turant gaane sunna shuru karein. Aap baad me Settings se apna account Gmail se jod sakenge:",
              style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Aapka Naam (e.g. Harsh)",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    final name = _nameController.text.trim();
                    Navigator.pop(context);
                    Get.find<PeaceAuthService>().loginAsGuest(name.isEmpty ? "Guest User" : name);
                  },
                  child: const Text("Start Listening", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Google Fast Login Dialog
class GoogleLoginDialog extends StatefulWidget {
  const GoogleLoginDialog({super.key});

  @override
  State<GoogleLoginDialog> createState() => _GoogleLoginDialogState();
}

class _GoogleLoginDialogState extends State<GoogleLoginDialog> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.g_mobiledata_rounded, color: Colors.blueAccent, size: 36),
                SizedBox(width: 8),
                Text(
                  "Google Sign-In",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Apna Gmail aur Naam dalein jisse aapka account direct Google cloud sync se connect ho jaye:",
              style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Aapka Naam (Full Name)",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Gmail Address (e.g. name@gmail.com)",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    final email = _emailController.text.trim();
                    final name = _nameController.text.trim();
                    if (!email.contains('@')) {
                      Get.find<PeaceAuthService>().showCustomSnackBar("Kripya valid Gmail address enter karein.", title: "Invalid Email");
                      return;
                    }
                    Navigator.pop(context);
                    Get.find<PeaceAuthService>().loginWithGoogle(email, name);
                  },
                  child: const Text("Connect & Sync", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
