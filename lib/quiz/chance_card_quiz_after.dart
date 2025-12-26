import 'package:flutter/material.dart';
import 'chance_card.dart';
import 'chance_card_repository.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart'; // 안개 효과 애니메이션용
import 'dart:ui'; // Blur 효과용 (ImageFilter)
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
  
  // 이로운 효과용 컨트롤러 (양쪽)
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

    // 양쪽 폭죽 컨트롤러 초기화
    _leftConfettiController = ConfettiController(duration: const Duration(seconds: 3));
    _rightConfettiController = ConfettiController(duration: const Duration(seconds: 3));

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
          // 1. 기본 어두운 배경
          Container(
            width: size.width,
            height: size.height,
            color: Colors.black.withOpacity(0.6),
          ),

          // 2. [해로운 효과] 검은 안개 + 블러 (카드가 결정되고 나쁜 카드일 때 표시)
          if (_hasPlayedEffect && !_isGood)
            Positioned.fill(
              child: Animate()
                  .fadeIn(duration: 1500.ms) // 서서히 나타남
                  .custom(
                    builder: (context, value, child) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10 * value, sigmaY: 10 * value),
                        child: Container(
                          color: Colors.black.withOpacity(0.6 * value), // 점점 더 어두워짐
                        ),
                      );
                    },
                  ),
            ),

          // 3. 카드 (중앙 배치)
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.height * 0.5,
                  maxHeight: size.height * 0.85,
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

          // 4. [이로운 효과] 양쪽 폭죽
          if (_hasPlayedEffect && _isGood) ...[
            // 왼쪽에서 오른쪽 위로 발사
            Align(
              alignment: Alignment.centerLeft,
              child: ConfettiWidget(
                confettiController: _leftConfettiController,
                blastDirection: -pi / 3, // 오른쪽 위 대각선
                emissionFrequency: 0.05,
                numberOfParticles: 10,
                maxBlastForce: 20,
                minBlastForce: 10,
                gravity: 0.2,
                colors: const [Color(0xffbb0000), Color(0xffffffff)], // 요청하신 빨강/흰색
              ),
            ),
            // 오른쪽에서 왼쪽 위로 발사
            Align(
              alignment: Alignment.centerRight,
              child: ConfettiWidget(
                confettiController: _rightConfettiController,
                blastDirection: -pi * 2 / 3, // 왼쪽 위 대각선
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
              child: Icon(Icons.style_outlined, size: 64, color: Color(0xFFD4C4A8)),
            ),
          );
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
            // 이로운 효과일 때만 폭죽 실행
            if (_isGood) {
              _leftConfettiController.play();
              _rightConfettiController.play();
            }
          });
        }

        // --- 기존 레이아웃 유지 ---
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Text(
                  card.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD4C4A8), width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.asset(
                        'assets/island_storm.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              nextIsGood ? Icons.celebration : Icons.warning_amber_rounded,
                              size: 48,
                              color: nextIsGood ? Colors.orange : Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      if (widget.quizEffect && !isCorrectionFailed)
                        _infoChip("이로운 효과 확률 상승!", const Color(0xFF2E7D32)),

                      if (isCorrectionFailed)
                        _infoChip("운이 따르지 않았습니다...", const Color(0xFFD84315)),

                      const SizedBox(height: 12),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            card.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Color(0xFF4E342E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5D4037),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 4,
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
                      const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        border: Border.all(color: textColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
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
