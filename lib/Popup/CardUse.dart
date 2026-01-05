import 'dart:async'; // 💡 타이머 추가
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CardUseDialog extends StatefulWidget {
  final int user;

  const CardUseDialog({
    super.key,
    required this.user,
  });

  @override
  State<CardUseDialog> createState() => _CardUseDialogState();
}
class _CardUseDialogState extends State<CardUseDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  String cardType = "N";
  bool isLoading = true;

  // 💡 타이머 관련 변수
  Timer? _autoTimer;
  int _remainingTime = 10;

  @override
  void initState() {
    super.initState();
    _getCardFromDB().then((_) {
      if (!isLoading) _startAutoTimer();
    });
  }

  void _startAutoTimer() {
    _autoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _autoTimer?.cancel();
          Navigator.pop(context);
        }
      });
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel(); // 타이머 해제
    super.dispose();
  }

  Future<void> _getCardFromDB() async {
    try {
      final snap = await fs.collection("games").doc("users").get();
      if (snap.exists && mounted) {
        setState(() {
          cardType = snap.data()!["user${widget.user}"]["card"] ?? "N";
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _useCardAction() async {
    if (cardType == "shield") {
      await fs.collection("games").doc("users").update({"user${widget.user}.card": "N"});
    } else if (cardType == "escape") {
      await fs.collection("games").doc("users").update({
        "user${widget.user}.card": "N",
        "user${widget.user}.islandCount": 0
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    // 카드 타입에 따른 상황 메시지 설정
    String statusMessage = cardType == "shield" 
        ? "비싼 통행료를 내야 할 위기입니다!" 
        : "무인도에 갇혀버렸습니다!";
    
    IconData statusIcon = cardType == "shield" 
        ? Icons.monetization_on 
        : Icons.explore;

    return Material(
      color: Colors.black.withOpacity(0.6),
      child: Stack(
        children: [
          // 💡 [타이머 표시 - 우측 상단]
          Positioned(
            top: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "$_remainingTime초 후 자동 취소",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // [상황 기반 메시지 바 - 자동 생성]
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: cardType == "shield" ? Colors.redAccent : Colors.blueAccent),
                      const SizedBox(width: 10),
                      Text(
                        statusMessage,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4E342E),
                        ),
                      ),
                    ],
                  ),
                ),

                // [카드 본체]
                Container(
                  width: 220,
                  height: 310,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF5E6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF5D4037), width: 6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 카드 제목 바
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF5D4037),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        child: Text(
                          cardType == "shield" ? "vip명찰" : "무인도 탈출권",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 카드 이미지
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              cardType == "shield" ? 'assets/cards/c_shield.png' : 'assets/cards/c_escape.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, size: 50),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // 카드 설명
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              cardType == "shield" 
                                ? "VIP의 특권!\n통행료를 한 번 면제할 수 있습니다."
                                : "무인도에서\n즉시 탈출할 수 있습니다.",
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
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // 💡 [버튼 영역]
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton("사용하기", const Color(0xFF5D4037), () async {
                      _autoTimer?.cancel();
                      await _useCardAction();
                      if (mounted) Navigator.pop(context, true);
                    }),
                    const SizedBox(width: 20),
                    _actionButton("취소", Colors.grey[700]!,
                     () {
                      _autoTimer?.cancel();
                      Navigator.pop(context);
                    }, isOutline: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String text, Color color, VoidCallback onTap, {bool isOutline = false}) {
    if (isOutline) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.8), color],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black26, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 8),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}