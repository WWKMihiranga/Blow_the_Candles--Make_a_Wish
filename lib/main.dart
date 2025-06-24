import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:confetti/confetti.dart';

void main() {
  runApp(const BirthdayApp());
}

class BirthdayApp extends StatelessWidget {
  const BirthdayApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Happy Birthday',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.15,
          ),
        ),
      ),
      home: const BirthdayHomePage(),
    );
  }
}

class BirthdayHomePage extends StatefulWidget {
  const BirthdayHomePage({Key? key}) : super(key: key);

  @override
  _BirthdayHomePageState createState() => _BirthdayHomePageState();
}

class _BirthdayHomePageState extends State<BirthdayHomePage>
    with TickerProviderStateMixin {
  bool _isCandleLit = true;
  bool _hasBlown = false;
  bool _showInstructions = true;
  double _blowProgress = 0.0;

  // Animation Controllers
  late AnimationController _flameController;
  late AnimationController _instructionController;
  late AnimationController _celebrationController;
  late AnimationController _backgroundController;
  late AnimationController _progressController;

  // Animations
  late Animation<double> _flameAnimation;
  late Animation<double> _instructionOpacity;
  late Animation<double> _celebrationScale;
  late Animation<Color?> _backgroundAnimation;
  late Animation<double> _progressAnimation;

  late ConfettiController _confettiController;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  double _lastZ = 0;
  int _blowCount = 0;
  Timer? _blowTimer;
  Timer? _instructionTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeConfetti();
    _startInstructionAnimation();
    _startListeningToSensors();

    // Show initial guidance
    Future.delayed(const Duration(seconds: 1), () {
      _showGuidanceDialog();
    });
  }

  void _initializeAnimations() {
    // Flame flickering animation
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flameAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _flameController,
      curve: Curves.easeInOut,
    ));
    _flameController.repeat();

    // Instruction pulsing
    _instructionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _instructionOpacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _instructionController, curve: Curves.easeInOut),
    );
    _instructionController.repeat(reverse: true);

    // Celebration animation
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _celebrationScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );

    // Background color transition
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _backgroundAnimation = ColorTween(
      begin: const Color(0xFFFCE4EC),
      end: const Color(0xFFF8BBD9),
    ).animate(_backgroundController);

    // Progress animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
  }

  void _initializeConfetti() {
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 8));
  }

  void _startInstructionAnimation() {
    _instructionTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isCandleLit && !_hasBlown) {
        setState(() {
          _showInstructions = !_showInstructions;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _showGuidanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.pink[400], size: 28),
              const SizedBox(width: 12),
              const Text('Birthday Magic  ✨'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hold your phone upright and gently blow on the screen to extinguish the candle',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.pink[400], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pro tip: Multiple quick puffs work best',
                        style: TextStyle(
                            fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startListeningToSensors() async {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final double z = event.z;
      final double delta = z - _lastZ;
      _lastZ = z;

      // Enhanced blow detection with progress tracking
      if (delta.abs() > 1.2 && _isCandleLit && !_hasBlown) {
        _blowCount++;

        // Update progress
        setState(() {
          _blowProgress = (_blowCount / 5.0).clamp(0.0, 1.0);
        });

        // Animate progress
        _progressController.forward().then((_) {
          _progressController.reverse();
        });

        // Haptic feedback
        HapticFeedback.lightImpact();

        if (_blowTimer == null || !_blowTimer!.isActive) {
          _blowTimer = Timer(const Duration(seconds: 3), () {
            setState(() {
              _blowCount = 0;
              _blowProgress = 0.0;
            });
          });
        }

        if (_blowCount >= 5) {
          _extinguishCandle();
        }
      }
    });
  }

  void _extinguishCandle() {
    setState(() {
      _isCandleLit = false;
      _hasBlown = true;
      _showInstructions = false;
    });

    // Stop flame animation
    _flameController.stop();
    _instructionController.stop();

    // Start celebration
    _celebrationController.forward();
    _backgroundController.forward();
    _confettiController.play();

    // Strong haptic feedback
    HapticFeedback.heavyImpact();

    _accelerometerSubscription?.cancel();
  }

  void _resetExperience() {
    setState(() {
      _isCandleLit = true;
      _hasBlown = false;
      _showInstructions = true;
      _blowProgress = 0.0;
      _blowCount = 0;
    });

    _flameController.repeat();
    _instructionController.repeat(reverse: true);
    _celebrationController.reset();
    _backgroundController.reset();

    _startListeningToSensors();
  }

  @override
  void dispose() {
    _flameController.dispose();
    _instructionController.dispose();
    _celebrationController.dispose();
    _backgroundController.dispose();
    _progressController.dispose();
    _confettiController.dispose();
    _accelerometerSubscription?.cancel();
    _blowTimer?.cancel();
    _instructionTimer?.cancel();
    super.dispose();
  }

  Widget _buildEnhancedCandle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Progress indicator
        if (_isCandleLit && _blowProgress > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Text(
                  'Keep blowing ${(_blowProgress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.pink[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.pink[100],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: _blowProgress,
                    alignment: Alignment.centerLeft,
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.pink[300]!, Colors.pink[500]!],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withOpacity(0.4),
                                blurRadius: 4 * _progressAnimation.value,
                                spreadRadius: 1 * _progressAnimation.value,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Enhanced Candle with 3D effect
        Stack(
          alignment: Alignment.topCenter,
          children: [
            // Candle body with gradient and shadow
            Column(
              children: [
                Container(
                  width: 50,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        const Color(0xFFF5F5F5),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(-3, 5),
                      ),
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                // Enhanced candle base
                Container(
                  width: 90,
                  height: 25,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.pink[200]!, Colors.pink[400]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Enhanced flame with realistic glow
            if (_isCandleLit)
              AnimatedBuilder(
                animation: _flameAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _flameAnimation.value,
                    child: Container(
                      width: 35,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, 0.3),
                          radius: 0.8,
                          colors: [
                            const Color(0xFFFFEB3B),
                            const Color(0xFFFF9800),
                            const Color(0xFFFF5722),
                            Colors.red.withOpacity(0.1),
                          ],
                          stops: const [0.0, 0.4, 0.7, 1.0],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Realistic smoke animation when extinguished
            if (!_isCandleLit)
              TweenAnimationBuilder(
                duration: const Duration(seconds: 3),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: (1 - value).clamp(0.0, 0.8),
                    child: Transform.translate(
                      offset: Offset(
                        math.sin(value * 4 * math.pi) * 10,
                        -value * 80,
                      ),
                      child: Container(
                        width: 25 + (value * 15),
                        height: 25 + (value * 15),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.grey.withOpacity(0.6),
                              Colors.grey.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return AnimatedBuilder(
      animation: _instructionOpacity,
      builder: (context, child) {
        return AnimatedOpacity(
          opacity: _showInstructions ? _instructionOpacity.value : 0.3,
          duration: const Duration(milliseconds: 500),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.pink[50]!.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Blow gently on the screen',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.pink[700],
                                fontWeight: FontWeight.w700,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'to make a birthday wish come true !!! 🌟🌟🌟🌟🌟',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.pink[600],
                            fontStyle: FontStyle.italic,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 48,
                  color: Colors.pink[400],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCelebration() {
    return AnimatedBuilder(
      animation: _celebrationScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _celebrationScale.value,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.pink[50]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'HAPPY BIRTHDAY\n💐❤️',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.pink[700],
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Wishing you a day\nas special as you are',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.pink[600],
                                fontStyle: FontStyle.italic,
                                height: 1.3,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pink[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Kavindu',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.pink[800],
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _resetExperience,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Blow Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _backgroundAnimation.value ?? const Color(0xFFFCE4EC),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildEnhancedCandle(),
                          const SizedBox(height: 60),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 800),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _isCandleLit
                                ? _buildInstructions()
                                : _buildCelebration(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Enhanced confetti
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        Colors.pink,
                        Colors.red,
                        Colors.yellow,
                        Colors.white,
                        Colors.orange,
                        Colors.purple,
                      ],
                      numberOfParticles: 50,
                      gravity: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
