import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IslandDialog extends StatefulWidget {
  final int user;
  final Map<String, dynamic>? gameState; // 부모로부터 최신 상태를 받음

  const IslandDialog({super.key, required this.user, this.gameState});

  @override
  State<IslandDialog> createState() => _IslandDialogState();
}

class _IslandDialogState extends State<IslandDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  bool _isProcessing = false; // 중복 클릭 방지용

  @override
  Widget build(BuildContext context) {
    // 💡 여기서 gameState가 null이 아니면 바로 데이터를 뽑아 씁니다.
    final userData = widget.gameState?['users']?['user${widget.user}'] ?? {};
    final int turn = userData['islandCount'] ?? 0;
    final int currentMoney = userData['money'] ?? 0;

    final size = MediaQuery.of(context).size;

    /// 💰 결제 로직 (gameState 데이터를 기반으로 실행)
    Future<void> payment() async {
      if (_isProcessing) return; // 이미 처리 중이면 무시
      setState(() => _isProcessing = true);

      try {
        // 로컬/온라인 공용 Firestore 경로 업데이트
        await fs.collection("games").doc("users").update({
          "user${widget.user}.money": FieldValue.increment(-1000000),
          "user${widget.user}.totalMoney": FieldValue.increment(-1000000),
          "user${widget.user}.islandCount": 0
        });

        // 💡 Navigator 에러 방지: 위젯이 아직 화면에 있을 때만 닫기
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        print("결제 오류: $e");
        if (mounted) setState(() => _isProcessing = false);
      }
    }

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
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              alignment: Alignment.center,
              child: const Text("🏝 무인도", style: TextStyle(fontSize: 22, color: Color(0xFFFFE082), fontWeight: FontWeight.bold)),
            ),

            /// 본문
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("무인도 탈출 비용: 100만 원\n(현재 잔액: ${currentMoney ~/ 10000}만 원)", textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text("$turn 턴 동안 대기해야 합니다.", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      onPressed: (_isProcessing || currentMoney < 1000000) ? null : payment,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63)),
                      child: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("100만 지불", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
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