import 'package:flutter/material.dart';
import 'chance_card.dart';
import 'chance_card_repository.dart';
import 'package:lottie/lottie.dart';

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

  // 🔒 랜덤 카드 1회 고정
  late final Future<ChanceCard> _cardFuture;

  // 상태값
  bool _fxPlaying = false;
  bool _isGood = true;

  @override
  void initState() {
    super.initState();

    // 카드 회전 애니메이션
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

    // 랜덤 카드 딱 1번만
    _cardFuture = ChanceCardRepository.fetchRandom(
      quizCorrect: widget.quizEffect,
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 어두운 배경
          Container(
            width: size.width,
            height: size.height,
            color: Colors.black.withOpacity(0.6), // 배경 조금 더 어둡게
          ),

          // 카드 (중앙 배치)
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.height * 0.6, // 가로 너비 제한 (비율 유지)
                  maxHeight: size.height * 0.9,
                ),
                child: AspectRatio(
                  aspectRatio: 2 / 3.2, // 카드 비율
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

          // 전체 화면 이펙트 (카드 위)
          if (_fxPlaying)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: _isGood
                      ? const Offset(0, 10)
                      : const Offset(0, 0),
                  child: Transform.scale(
                    scale: _isGood ? 0.8 : 1.0,
                    child: Lottie.asset(
                      _isGood
                          ? 'assets/lottie/benefit_effect.json'
                          : 'assets/lottie/harm_effect.json',
                      fit: BoxFit.cover,
                      repeat: false,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===============================
  // 카드 UI
  // ===============================
  Widget _buildCard() {
    return FutureBuilder<ChanceCard>(
      future: _cardFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // 로딩 중일 때 카드 뒷면 느낌
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4C4A8), width: 3),
            ),
            child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4C4A8))),
          );
        }

        final card = snapshot.data!;
        final bool nextIsGood = card.type == 'benefit';
        final bool isCorrectionFailed = widget.quizEffect && !nextIsGood;

        // 상태 동기화 (안전)
        if (_isGood != nextIsGood) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _isGood = nextIsGood;
            });
          });
        }

        if (!_fxPlaying) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _fxPlaying = true;
            });
          });
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6), // 한지 배경
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5D4037), width: 6), // 나무 테두리
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
              // 제목 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Text(
                  card.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700), // 금색
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              // 이미지 영역
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD4C4A8), width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.asset(
                        'assets/cards/island_storm.png', // 더미 이미지
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              // 내용 영역
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      // 확률 보정 칩
                      if (widget.quizEffect && !isCorrectionFailed)
                        _infoChip(
                          "이로운 효과 확률 상승!",
                          const Color(0xFF2E7D32),
                        ),

                      if (isCorrectionFailed)
                        _infoChip(
                          "운이 따르지 않았습니다...",
                          const Color(0xFFD84315),
                        ),

                      const SizedBox(height: 8),

                      // 카드 설명
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            card.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF4E342E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 확인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 38,
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
                            setState(() {
                              _fxPlaying = false;
                            });
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        border: Border.all(color: textColor.withOpacity(0.5)),
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