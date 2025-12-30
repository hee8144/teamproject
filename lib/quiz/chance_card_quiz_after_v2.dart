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
  
  // [핵심 로직] 카드 액션 처리
  Future<void> _handleCardAction(ChanceCard card) async {
    try {
      String currentCard = 'N';
      String docId = 'unknown';

      // 1. 데이터 가져오기
      if (ChanceCardQuizAfterV2.isTestMode) {
        debugPrint("🛠️ [TestMode] 유저 데이터 조회 중...");
        currentCard = ChanceCardQuizAfterV2.testUserMock['card'] ?? 'N';
        docId = 'test_user_doc_id';
        debugPrint("🛠️ [TestMode] 현재 보유 카드: $currentCard");
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('turn', isEqualTo: 0)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          if (mounted) Navigator.pop(context, card.description);
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
          // 이미 카드가 있음 -> [수정됨] 비교 팝업 호출 (새 카드 정보도 전달)
          if (mounted) {
            _showCompareDialog(
              docId, 
              currentCard, 
              newCardCode, 
              card.title, 
              card.imageKey ?? card.action, // 새 카드 이미지 키
              card.description
            );
          }
        } else {
          // 카드 없음 -> 바로 획득
          await _updateUserCard(docId, newCardCode);
          if (mounted) Navigator.pop(context, card.description);
        }
      } else {
        // 즉시 효과 카드 등
        if (mounted) Navigator.pop(context, card.description);
      }
    } catch (e) {
      debugPrint("Error handling card action: $e");
      if (mounted) Navigator.pop(context, card.description);
    }
  }

  // [내부 함수] DB 업데이트
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

  // [UI] 카드 이미지 경로 헬퍼
  String _getImagePath(String codeOrKey) {
    // 1. 이미 assets/ 경로가 포함된 경우 (없겠지만 방어 코드)
    if (codeOrKey.startsWith('assets/')) return codeOrKey;

    // 2. 코드(escape, sheild)를 이미지 키(c_escape, c_shield)로 변환
    String imageKey = codeOrKey;
    if (codeOrKey == 'escape') imageKey = 'c_escape';
    if (codeOrKey == 'sheild') imageKey = 'c_shield'; // 오타 주의

    // 3. 최종 경로 반환
    return 'assets/cards/$imageKey.png';
  }

  // [UI] 카드 비교 및 교체 다이얼로그
  void _showCompareDialog(
      String docId, 
      String oldCardCode, 
      String newCardCode, 
      String newCardTitle, 
      String newCardImageKey,
      String description) {
    
    final String oldCardName = (oldCardCode == 'escape') ? '무인도 탈출' : 'VIP 명찰';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600, // 넉넉한 너비
          height: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF5D4037), width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "⚠️ 보관함이 가득 찼습니다!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFD84315)),
              ),
              const SizedBox(height: 8),
              const Text("하나만 선택하여 보관할 수 있습니다.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              Expanded(
                child: Row(
                  children: [
                    // [좌측] 기존 카드
                    Expanded(
                      child: _buildCompareCardItem(
                        title: oldCardName,
                        imagePath: _getImagePath(oldCardCode),
                        label: "보유 중",
                        labelColor: Colors.blueGrey,
                        isNew: false,
                      ),
                    ),
                    
                    // [중앙] VS 아이콘
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.swap_horiz, size: 40, color: Color(0xFF5D4037)),
                          Text("VS", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                        ],
                      ),
                    ),
                    
                    // [우측] 새 카드
                    Expanded(
                      child: _buildCompareCardItem(
                        title: newCardTitle,
                        imagePath: _getImagePath(newCardImageKey),
                        label: "새로 획득",
                        labelColor: Colors.amber[800]!,
                        isNew: true,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // [하단 버튼]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      // 기존 유지 (버리기)
                      debugPrint("🛠️ [TestMode] 카드 버림 (기존 유지)");
                      Navigator.pop(dialogContext);
                      Navigator.pop(context, description);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("새 카드 버리기"),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      // 교체하기
                      await _updateUserCard(docId, newCardCode);
                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      Navigator.pop(context, description);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("새 카드로 교체"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // [UI] 비교용 카드 아이템 위젯
  Widget _buildCompareCardItem({
    required String title,
    required String imagePath,
    required String label,
    required Color labelColor,
    required bool isNew,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew ? const Color(0xFF5D4037) : Colors.grey.shade400,
          width: isNew ? 2.5 : 1,
        ),
        boxShadow: [
          if (isNew) BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 8, spreadRadius: 2),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isNew ? const Color(0xFF4E342E) : Colors.grey[700],
            ),
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
          // 2. 안개 효과
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
          // 3. 카드 회전 애니메이션
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
          // 4. 폭죽
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
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

              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
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
                            ? 'assets/cards/${card.imageKey}.png'
                            : 'assets/cards/island_storm2.png',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Column(
                    children: [
                      if (widget.quizEffect && !isCorrectionFailed)
                        _infoChip("이로운 효과 확률 상승!", const Color(0xFF2E7D32)),

                      if (isCorrectionFailed)
                        _infoChip("운이 따르지 않았습니다...", const Color(0xFFD84315)),

                      const SizedBox(height: 6),

                      Expanded(
                        child: Center(
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
                      ),

                      const SizedBox(height: 6),

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
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            _leftConfettiController.stop();
                            _rightConfettiController.stop();
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
