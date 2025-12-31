import 'package:flutter/material.dart';
import 'chance_card.dart';
import 'chance_card_repository.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:math';

class ChanceCardQuizAfter extends StatefulWidget {
  final bool quizEffect;

  const ChanceCardQuizAfter({
    super.key,
    required this.quizEffect,
  });

  @override
  State<ChanceCardQuizAfter> createState() => _ChanceCardQuizAfterState();
}

class _ChanceCardQuizAfterState extends State<ChanceCardQuizAfter>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final Animation<double> _rotation;

  late ConfettiController _leftConfettiController;
  late ConfettiController _rightConfettiController;

  late final Future<ChanceCard> _cardFuture;

  bool _isGood = true;
  bool _hasPlayedEffect = false;

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _rotation = Tween<double>(
      begin: -1.57,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _rotateController,
        curve: Curves.easeOutCubic,
      ),
    );

    _rotateController.forward();

    _leftConfettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _rightConfettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _cardFuture = ChanceCardRepository.fetchRandom(
      quizCorrect: widget.quizEffect,
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _leftConfettiController.dispose();
    _rightConfettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 배경
          Container(
            width: size.width,
            height: size.height,
            color: Colors.black.withOpacity(0.6),
          ),

          // 해로운 카드 이펙트
          if (_hasPlayedEffect && !_isGood)
            Positioned.fill(
              child: Animate()
                  .fadeIn(duration: 1500.ms)
                  .custom(
                builder: (context, value, child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10 * value,
                      sigmaY: 10 * value,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(0.6 * value),
                    ),
                  );
                },
              ),
            ),

          // 카드 애니메이션
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0.0, -0.3),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.height * 0.75,
                  maxHeight: size.height * 0.95,
                ),
                child: AspectRatio(
                  aspectRatio: 2 / 3.2,
                  child: AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, child) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(_rotation.value),
                        child: child,
                      );
                    },
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
          ),

          // 이로운 카드 폭죽
          if (_hasPlayedEffect && _isGood) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ConfettiWidget(
                confettiController: _leftConfettiController,
                blastDirection: -pi / 3,
                emissionFrequency: 0.05,
                numberOfParticles: 10,
                maxBlastForce: 20,
                minBlastForce: 10,
                gravity: 0.2,
                colors: const [Color(0xffbb0000), Color(0xffffffff)],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ConfettiWidget(
                confettiController: _rightConfettiController,
                blastDirection: -pi * 2 / 3,
                emissionFrequency: 0.05,
                numberOfParticles: 10,
                maxBlastForce: 20,
                minBlastForce: 10,
                gravity: 0.2,
                colors: const [Color(0xffbb0000), Color(0xffffffff)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard() {
    return FutureBuilder<ChanceCard>(
      future: _cardFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4C4A8), width: 3),
            ),
            child: const Center(
              child: Icon(Icons.style_outlined,
                  size: 64, color: Color(0xFFD4C4A8)),
            ),
          );
        }

        final card = snapshot.data!;
        final bool nextIsGood = card.type == 'benefit';
        final bool isCorrectionFailed =
            widget.quizEffect && !nextIsGood;

        if (!_hasPlayedEffect) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _isGood = nextIsGood;
              _hasPlayedEffect = true;
            });
            if (_isGood) {
              _leftConfettiController.play();
              _rightConfettiController.play();
            }
          });
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5D4037), width: 6),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Text(
                  card.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.asset(
                    'assets/cards/${card.imageKey}.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
                    },
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Column(
                    children: [
                      if (widget.quizEffect && !isCorrectionFailed)
                        _infoChip(
                            "이로운 효과 확률 상승!", const Color(0xFF2E7D32)),

                      if (isCorrectionFailed)
                        _infoChip("운이 따르지 않았습니다...",
                            const Color(0xFFD84315)),

                      const SizedBox(height: 6),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            card.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF4E342E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF5D4037),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _leftConfettiController.stop();
                            _rightConfettiController.stop();

                            // 💡 GameMain으로 action 문자열을 그대로 전달 (예: "c_escape", "d_tax")
                            Navigator.pop(context, card.action);
                          },
                          child: const Text(
                            "확 인",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        border: Border.all(color: textColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}