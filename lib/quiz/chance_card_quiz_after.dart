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

  late ConfettiController _leftConfettiController;
  late ConfettiController _rightConfettiController;

  late final Future<ChanceCard> _cardFuture;

  @override
  void initState() {
    super.initState();

    // 1. 회전 애니메이션 (빙그르르)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _rotation = Tween<double>(begin: -pi / 2, end: 0.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeOutCubic),
    );

    _rotateController.forward();

    // 2. 폭죽 설정 (좌/우)
    _leftConfettiController = ConfettiController(duration: const Duration(seconds: 3));
    _rightConfettiController = ConfettiController(duration: const Duration(seconds: 3));

    // 3. 데이터 로드
    _cardFuture = widget.debugCard != null 
        ? Future.value(widget.debugCard!) 
        : ChanceCardRepository.fetchRandom(quizCorrect: widget.quizEffect);
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
                final bool isStorage = card.action == "c_shield" || card.action == "c_escape";
                final bool hasStored = widget.storedCard != "N";

                // 이로운 카드일 때 양옆 폭죽 발사
                if (card.type == 'benefit') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _leftConfettiController.play();
                    _rightConfettiController.play();
                  });
                }

                return AnimatedBuilder(
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

  Widget _singleMode(ChanceCard card, bool isStorage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _cardFrame(card: card),
        const SizedBox(height: 14),
        _actionButton("확 인", () {
          Navigator.pop(context, isStorage ? "store:${card.action}" : card.action);
        }),
      ],
    );
  }

  Widget _compareMode(String oldCardKey, ChanceCard newCard) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _simpleCard(oldCardKey),
            const SizedBox(width: 40),
            _cardFrame(card: newCard),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton("교체하기", () => Navigator.pop(context, "replace:${newCard.action}")),
            const SizedBox(width: 20),
            _actionButton("버리기", () => Navigator.pop(context, "discard"), isGrey: true),
          ],
        ),
      ],
    );
  }

  Widget _cardFrame({required ChanceCard card}) {
    return Container(
      width: 240,
      height: 340,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5D4037), width: 6),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 8))],
      ),
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
          
          // 💡 퀴즈 정답 시 카드 타입에 따른 분기 표시
          if (widget.quizEffect)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: card.type == 'benefit'
                  ? _infoChip("이로운 효과 확률 상승!", const Color(0xFF2E7D32))
                  : _infoChip("운이 따르지 않았습니다...", const Color(0xFFD84315)),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isGrey ? Colors.grey[700] : const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
      ),
      onPressed: onTap,
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
