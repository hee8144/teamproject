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
          Container(
            width: size.width,
            height: size.height,
            color: Colors.black.withOpacity(0.6),
          ),

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

          /// 🎴 카드
          Positioned.fill(
            child: Center(
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
                child: SizedBox(
                  width: size.width * 0.75,
                  height: size.height * 0.8,
                  child: _buildCard(),
                ),
              ),
            ),
          ),

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
          return _loadingCard();
        }

        final card = snapshot.data!;
        final bool nextIsGood = card.type == 'benefit';
        final bool isCorrectionFailed = widget.quizEffect && !nextIsGood;

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
            borderRadius: BorderRadius.circular(18),
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
              /// 제목
              Container(
                height: 45,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),

              /// ===== 중앙 영역 (유동) =====
              Expanded(
                child: Column(
                  children: [
                    /// 이미지
                    Flexible(
                      flex: 4, // ⭐ 이미지가 차지하는 비율
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Image.asset(
                              'assets/cards/island_storm2.png',
                            ),
                          ),
                        ),
                      ),
                    ),

                    /// 효과 칩
                    if (widget.quizEffect && !isCorrectionFailed)
                      _infoChip(
                          "이로운 효과 확률 상승!", const Color(0xFF2E7D32)),
                    if (isCorrectionFailed)
                      _infoChip("운이 따르지 않았습니다...",
                          const Color(0xFFD84315)),

                    const SizedBox(height: 6),

                    /// 설명
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        card.description,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: Color(0xFF4E342E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              /// ===== 하단 버튼 (항상 고정) =====
              Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      _leftConfettiController.stop();
                      _rightConfettiController.stop();
                      Navigator.pop(context, card.description);
                    },
                    child: const Text(
                      "확 인",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Icon(Icons.style_outlined,
            size: 64, color: Color(0xFFD4C4A8)),
      ),
    );
  }

  Widget _infoChip(String text, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
