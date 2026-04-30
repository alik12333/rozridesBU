import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Controllers ───────────────────────────────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _orbController;
  late final AnimationController _shimmerController;
  late final AnimationController _progressController;

  // ─── Animations ────────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _shimmer;
  late final Animation<double> _progress;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Logo: scale + fade
    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _logoScale = CurvedAnimation(
        parent: _logoController, curve: Curves.easeOutBack);
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: const Interval(0, 0.6)));

    // Text: fade + slide up
    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Orbs: continuous rotation
    _orbController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    // Shimmer on text
    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.linear));

    // Progress bar
    _progressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800));
    _progress = CurvedAnimation(
        parent: _progressController, curve: Curves.easeInOut);

    _runSequence();
  }

  Future<void> _runSequence() async {
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();
    _progressController.forward();

    // Navigate after 2.8s — fast enough to not feel slow
    await Future.delayed(const Duration(milliseconds: 2800));
    _navigate();
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => widget.nextScreen,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _orbController.dispose();
    _shimmerController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: Stack(children: [
        // ── Floating orbs background ──────────────────────────────────────
        AnimatedBuilder(
          animation: _orbController,
          builder: (_, __) {
            final t = _orbController.value * 2 * math.pi;
            return Stack(children: [
              // Top-left large orb
              Positioned(
                top: size.height * 0.05 + math.sin(t) * 20,
                left: -size.width * 0.2 + math.cos(t * 0.7) * 15,
                child: _Orb(diameter: size.width * 0.75,
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35)),
              ),
              // Bottom-right orb
              Positioned(
                bottom: size.height * 0.02 + math.cos(t) * 20,
                right: -size.width * 0.15 + math.sin(t * 0.9) * 15,
                child: _Orb(diameter: size.width * 0.65,
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
              ),
              // Centre accent orb
              Positioned(
                top: size.height * 0.5 + math.sin(t * 1.3) * 25,
                left: size.width * 0.55 + math.cos(t) * 10,
                child: _Orb(diameter: size.width * 0.35,
                    color: const Color(0xFFA855F7).withValues(alpha: 0.15)),
              ),
            ]);
          },
        ),

        // ── Subtle grid lines ─────────────────────────────────────────────
        CustomPaint(painter: _GridPainter(), size: size),

        // ── Main content ──────────────────────────────────────────────────
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Stack(alignment: Alignment.center, children: [
                    // Glow ring
                    Container(
                      width: 164,
                      height: 164,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          const Color(0xFF7C3AED).withValues(alpha: 0.5),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                    // White border
                    Container(
                      width: 144,
                      height: 144,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    // Logo image
                    ClipOval(
                      child: Image.asset('logocir.png',
                          width: 136, height: 136, fit: BoxFit.cover),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 40),

              // Brand name + tagline with shimmer
              FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(children: [
                    // Shimmer brand name
                    AnimatedBuilder(
                      animation: _shimmer,
                      builder: (_, __) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: const [
                            Color(0xFFE2D9F3),
                            Colors.white,
                            Color(0xFFC084FC),
                            Colors.white,
                            Color(0xFFE2D9F3),
                          ],
                          stops: [
                            (_shimmer.value - 0.6).clamp(0.0, 1.0),
                            (_shimmer.value - 0.3).clamp(0.0, 1.0),
                            _shimmer.value.clamp(0.0, 1.0),
                            (_shimmer.value + 0.3).clamp(0.0, 1.0),
                            (_shimmer.value + 0.6).clamp(0.0, 1.0),
                          ],
                        ).createShader(bounds),
                        child: Text('RozRides',
                            style: GoogleFonts.outfit(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            )),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Your Journey, Our Priority',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w300,
                        )),
                  ]),
                ),
              ),

              const Spacer(flex: 2),

              // Progress bar
              FadeTransition(
                opacity: _textOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Column(children: [
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress.value,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C3AED)),
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Orb widget ─────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double diameter;
  final Color color;
  const _Orb({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );
}

// ── Subtle grid painter ────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
