import 'package:flutter/material.dart';
import 'chance_card.dart';
import 'chance_card_repository.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChanceCardQuizAfterV2 extends StatefulWidget {
  final bool quizEffect;

  const ChanceCardQuizAfterV2({
    super.key,
    required this.quizEffect,
  });

  // [테스트용 설정]
  static bool isTestMode = true; 
  
  // [테스트용 가짜 유저 데이터]
  static Map<String, dynamic> testUserMock = {
    'card': 'N', // 'N', 'escape', 'sheild'
    'turn': 0,
    'money': 7000000,
  };

  @override
  State<ChanceCardQuizAfterV2> createState() => _ChanceCardQuizAfterV2State();
}

class _ChanceCardQuizAfterV2State extends State<ChanceCardQuizAfterV2>
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
  
  // [핵심 로직] 카드 액션 처리 (테스트 모드 지원)
  Future<void> _handleCardAction(ChanceCard card) async {
    try {
      String currentCard = 'N';
      String docId = 'unknown';

      // 1. 데이터 가져오기 (테스트 모드 분기)
      if (ChanceCardQuizAfterV2.isTestMode) {
        currentCard = ChanceCardQuizAfterV2.testUserMock['card'] ?? 'N';
        docId = 'test_user_doc_id';
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('turn', isEqualTo: 0)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          // 💡 [수정] description 대신 action 반환
          if (mounted) Navigator.pop(context, card.action);
          return;
        }

        final userDoc = snapshot.docs.first;
        final userData = userDoc.data();
        currentCard = userData['card'] ?? 'N';
        docId = userDoc.id;
      }

      // 2. 뽑은 카드가 보관용 카드인지 판별
      String? newCardCode;
      if (card.action == 'c_escape') newCardCode = 'escape';
      if (card.action == 'c_shield') newCardCode = 'sheild';

      // 3. 로직 수행
      if (newCardCode != null) {
        if (currentCard == 'sheild' || currentCard == 'escape') {
          // 이미 카드가 있음 -> 교체 팝업
          if (mounted) {
            // 교체 팝업에도 card.action을 넘겨줘서 최종적으로 반환하게 해야 함
            _showReplaceDialog(docId, currentCard, newCardCode, card.title, card.action);
          }
        } else {
          // 카드 없음 -> 바로 획득
          await _updateUserCard(docId, newCardCode);
          // 💡 [수정] description 대신 action 반환
          if (mounted) Navigator.pop(context, card.action);
        }
      } else {
        // 즉시 효과 카드 등
        // 💡 [수정] description 대신 action 반환
        if (mounted) Navigator.pop(context, card.action);
      }
    } catch (e) {
      debugPrint("Error handling card action: $e");
      // 에러 시에도 일단 닫으며 action 반환 (null 대신)
      if (mounted) Navigator.pop(context, card.action);
    }
  }

  // [내부 함수] DB 업데이트 (테스트 모드 지원)
  Future<void> _updateUserCard(String docId, String newCardCode) async {
    if (ChanceCardQuizAfterV2.isTestMode) {
      debugPrint("🛠️ [TestMode] DB 업데이트: card -> $newCardCode");
      ChanceCardQuizAfterV2.testUserMock['card'] = newCardCode;
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .update({'card': newCardCode});
    }
  }

  // 교체 팝업 (action 인자 추가)
  void _showReplaceDialog(
      String docId, String oldCardCode, String newCardCode, String newCardTitle, String action) {

    final String oldCardName = (oldCardCode == 'escape') ? '무인도 탈출' : 'VIP 명찰';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("카드 보관함 확인", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "현재 보유 중인 카드: '$oldCardName'\n새로 뽑은 카드: '$newCardTitle'\n\n새 카드로 교체하시겠습니까?",
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 버리기
              Navigator.pop(dialogContext);
              // 💡 버렸더라도 카드는 뽑았으므로 action 반환 (GameMain에서 로그 등으로 확인 가능)
              Navigator.pop(context, action);
            },
            child: const Text("버리기", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // 교체하기
              await _updateUserCard(docId, newCardCode);

              if (!mounted) return;
              Navigator.pop(dialogContext);
              // 💡 교체 후 action 반환
              Navigator.pop(context, action);
            },
            child: const Text("교체하기"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. 배경
          Container(
            width: size.width,
            height: size.height,
            color: Colors.black.withOpacity(0.6),
          ),
          // 2. 해로운 효과 배경 (안개)
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
          // 3. 카드 회전 애니메이션 (UI 개선: backup 스타일 적용)
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.height * 0.6, // 너무 넓어지지 않게 제한
                  maxHeight: size.height * 0.9,
                ),
                child: AspectRatio(
                  aspectRatio: 2 / 3.2, // 카드 비율 고정
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
          // 4. 이로운 효과 폭죽
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

  // [UI 디자인] backup.dart 스타일 적용
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
              // 1. 헤더 (타이틀)
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              // 2. 이미지 액자
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
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
                        card.imageKey != null && card.imageKey!.isNotEmpty
                            ? 'assets/cards/${card.imageKey}'
                            : 'assets/cards/island_storm2.png', // 기본값
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

              // 3. 내용 및 버튼
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      if (widget.quizEffect && !isCorrectionFailed)
                        _infoChip("이로운 효과 확률 상승!", const Color(0xFF2E7D32)),

                      if (isCorrectionFailed)
                        _infoChip("운이 따르지 않았습니다...", const Color(0xFFD84315)),

                      const SizedBox(height: 10),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            card.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF4E342E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 36,
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
                            // [로직 연결] 확인 버튼 누르면 DB 처리 함수 호출
                            _handleCardAction(card);
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
                      const SizedBox(height: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        border: Border.all(color: textColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
