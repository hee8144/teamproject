import 'package:flutter/material.dart';
import 'chance_card.dart';
import 'chance_card_repository.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class ChanceCardQuizAfter extends StatefulWidget {
  final bool quizEffect;
  final String storedCard; // "N", "shield", "escape"
  final ChanceCard? debugCard;

  const ChanceCardQuizAfter({
    super.key,
    required this.quizEffect,
    required this.storedCard,
    this.debugCard,
  });

  @override
  State<ChanceCardQuizAfter> createState() => _ChanceCardQuizAfterState();
}

class _ChanceCardQuizAfterState extends State<ChanceCardQuizAfter>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final Animation<double> _rotation;
  
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  late ConfettiController _leftConfettiController;
  late ConfettiController _rightConfettiController;

  late final Future<ChanceCard> _cardFuture;
  ChanceCard? _loadedCard; // 💡 로드된 카드 저장용

  @override
  void initState() {
    super.initState();

    // 1. 애니메이션 및 폭죽 초기화
    _rotateController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _rotation = Tween<double>(begin: -6 * pi, end: 0.0).animate(CurvedAnimation(parent: _rotateController, curve: Curves.easeInOutQuart));
    
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _glowAnimation = Tween<double>(begin: 5.0, end: 25.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine));
    _glowController.repeat(reverse: true);

    _leftConfettiController = ConfettiController(duration: const Duration(seconds: 3));
    _rightConfettiController = ConfettiController(duration: const Duration(seconds: 3));

    // 2. 데이터 로드
    _cardFuture = widget.debugCard != null 
        ? Future.value(widget.debugCard!) 
        : ChanceCardRepository.fetchRandom(quizCorrect: widget.quizEffect);

    // 3. 💡 [수정] 애니메이션 종료 후 폭죽 발사
    _rotateController.forward().then((_) {
      if (_loadedCard != null && _loadedCard!.type == 'benefit') {
        _leftConfettiController.play();
        _rightConfettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _glowController.dispose();
    _leftConfettiController.dispose();
    _rightConfettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0.0, -0.4),
            child: FutureBuilder<ChanceCard>(
              future: _cardFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator(color: Colors.amber);

                final card = snapshot.data!;
                _loadedCard = card; // 💡 종료 후 폭죽 판단을 위해 저장
                
                final bool isStorage = card.action == "c_shield" || card.action == "c_escape";
                final bool hasStored = widget.storedCard != "N";

                return AnimatedBuilder(
                  animation: _rotation,
                  builder: (context, child) {
                    final double angle = _rotation.value;
                    // 💡 코사인 값이 양수면 앞면, 음수면 뒷면
                    final bool isFront = cos(angle) > 0;

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: isFront 
                          ? child // 앞면 (기존 카드 위젯)
                          : Transform( // 뒷면 (거울 반전 방지를 위해 pi만큼 더 회전)
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(pi),
                              child: _cardBack(),
                            ),
                    );
                  },
                  child: (isStorage && hasStored) 
                      ? _compareMode(widget.storedCard, card)
                      : _singleMode(card, isStorage),
                );
              },
            ),
          ),

          // 좌측 폭죽 (60도 방향)
          Align(
            alignment: Alignment.bottomLeft,
            child: ConfettiWidget(
              confettiController: _leftConfettiController,
              blastDirection: -pi / 3, 
              emissionFrequency: 0.05,
              numberOfParticles: 15,
              gravity: 0.2,
              colors: const [Color(0xffbb0000), Color(0xffffffff)],
            ),
          ),

          // 우측 폭죽 (120도 방향)
          Align(
            alignment: Alignment.bottomRight,
            child: ConfettiWidget(
              confettiController: _rightConfettiController,
              blastDirection: -2 * pi / 3,
              emissionFrequency: 0.05,
              numberOfParticles: 15,
              gravity: 0.2,
              colors: const [Color(0xffbb0000), Color(0xffffffff)],
            ),
          ),
        ],
      ),
    );
  }

  // 💡 카드 뒷면 위젯 추가
  Widget _cardBack() {
    return Container(
      width: 240,
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/cards/backOfCard.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // 1장 모드 (Stack으로 겹침 배치)
  Widget _singleMode(ChanceCard card, bool isStorage) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none, // 버튼이 카드 밖으로 살짝 나가도 보이게
      children: [
        _cardFrame(card: card), // 아래 레이어: 카드
        
        Positioned(
          bottom: -15, // 💡 카드 하단에 살짝 걸치게 배치
          child: _actionButton("확 인", () {
            Navigator.pop(context, isStorage ? "store:${card.action}" : card.action);
          }),
        ),
      ],
    );
  }

  Widget _compareMode(String oldCardKey, ChanceCard newCard) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _simpleCard(oldCardKey),
            
            // 두 카드 사이의 역동적인 교체 아이콘
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_glowAnimation.value / 50),
                    child: Icon(
                      Icons.swap_horizontal_circle,
                      size: 50,
                      color: Colors.amberAccent.withOpacity(0.8),
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 10),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            _cardFrame(card: newCard),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton("교체하기", () => Navigator.pop(context, "replace:${newCard.action}")),
            const SizedBox(width: 180),
            _actionButton("버리기", () => Navigator.pop(context, "discard"), isGrey: true),
          ],
        ),
      ],
    );
  }

  Widget _cardFrame({required ChanceCard card}) {
    // 💡 카드 타입에 따른 빛 색상 결정
    final Color glowColor = card.type == 'benefit' 
        ? Colors.amberAccent.withOpacity(0.6) 
        : Colors.redAccent.withOpacity(0.4);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 240,
          height: 340,
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5D4037), width: 6),
            // 💡 여러 겹의 그림자로 아우라 표현
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: _glowAnimation.value, 
                spreadRadius: _glowAnimation.value / 2,
              ),
              const BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 8)),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF5D4037),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              card.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          
          if (widget.quizEffect)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: card.type == 'benefit'
                  ? _infoChip("이로운 효과 확률 상승!", const Color(0xFF2E7D32))
                  : _infoChip("운이 따르지 않았습니다...", const Color(0xFFD84315)),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/cards/${card.imageKey}.png', fit: BoxFit.cover),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    card.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF4E342E), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _simpleCard(String cardKey) {
    final bool isShield = cardKey.contains("shield");
    final String imageKey = isShield ? "c_shield" : "c_escape";
    final String cardName = isShield ? "면제 카드" : "무인도 탈출권";
    final String description = isShield ? "통행료를 한번 면제할 수 있습니다." : "무인도에서 즉시 탈출할 수 있습니다.";

    return Opacity(
      opacity: 0.8,
      child: Container(
        width: 240,
        height: 340,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEBE9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8D6E63), width: 6),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF8D6E63),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Text(
                cardName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/cards/$imageKey.png', fit: BoxFit.cover),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF4E342E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _actionButton(String text, VoidCallback onTap, {bool isGrey = false}) {
    final Color mainColor = isGrey ? Colors.grey[700]! : const Color(0xFF5D4037);
    final Color topColor = isGrey ? Colors.grey[500]! : const Color(0xFF8D6E63); // 💡 윗부분 하이라이트

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          // 💡 그라데이션으로 입체감 부여
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, mainColor],
          ),
          borderRadius: BorderRadius.circular(15),
          // 💡 버튼 테두리 강조
          border: Border.all(
            color: Colors.black.withOpacity(0.3),
            width: 2,
          ),
          // 💡 강력한 3D 그림자 효과
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(0, 5), // 아래로 그림자 밀기
              blurRadius: 8,
            ),
            // 안쪽 밝은 테두리 효과 (선택사항)
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 0,
              spreadRadius: -1,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            // 💡 글자에도 입체감을 위한 그림자 추가
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(1, 2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
