import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IslandDialog extends StatefulWidget {
  final int user;
  final Map<String, dynamic>? gameState; // null이면 로컬, 있으면 온라인

  const IslandDialog({
    super.key,
    required this.user,
    this.gameState,
  });

  @override
  State<IslandDialog> createState() => _IslandDialogState();
}

class _IslandDialogState extends State<IslandDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int turn = 0;
  int money = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    if (widget.gameState != null) {
      /// 🌐 온라인 → gameState 사용
      final userData =
      widget.gameState!['users']['user${widget.user}'];

      turn = userData['islandCount'] ?? 0;
      money = userData['money'] ?? 0;
    } else {
      /// 🧍 로컬 → Firebase에서 직접 읽기
      _fetchFromFirebase();
    }
  }

  Future<void> _fetchFromFirebase() async {
    final snap =
    await fs.collection("games").doc("users").get();

    if (!mounted || !snap.exists) return;

    final data = snap.data()!;
    final userData = data['user${widget.user}'];

    setState(() {
      turn = userData['islandCount'] ?? 0;
      money = userData['money'] ?? 0;
    });
  }

  /// 💰 100만원 지불
  Future<void> _payment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      /// 🧍 로컬만 Firebase 직접 수정
      if (widget.gameState == null) {
        await fs.collection("games").doc("users").update({
          "user${widget.user}.money":
          FieldValue.increment(-1000000),
          "user${widget.user}.totalMoney":
          FieldValue.increment(-1000000),
          "user${widget.user}.islandCount": 0,
        });
      }

      /// 🌐 온라인 / 로컬 공통 → 부모에게 결과 전달
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      debugPrint("무인도 결제 오류: $e");
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: size.width * 0.9,
        height: size.height * 0.45,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F6F1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF8D6E63), width: 2),
        ),
        child: Column(
          children: [
            /// 헤더
            Container(
              height: 60,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF3E4A59),
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
              ),
              alignment: Alignment.center,
              child: const Text(
                "🏝 무인도",
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFFFE082),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /// 본문
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "무인도에 도착했습니다.\n"
                          "$turn 턴 동안 이동할 수 없습니다.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            "💰 구조 비용 100만원을 지불하면\n즉시 탈출할 수 있습니다.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "• 더블이 나오면 즉시 탈출\n"
                                "• $turn턴 경과 시 자동 탈출",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:  (money >= 1000000) ? _payment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D6E63),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        "100만원 지불",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text("주사위 굴리기"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
