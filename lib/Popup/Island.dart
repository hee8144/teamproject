import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IslandDialog extends StatefulWidget {
  final int user;
  const IslandDialog({super.key, required this.user});

  @override
  State<IslandDialog> createState() => _IslandDialogState();
}

class _IslandDialogState extends State<IslandDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  int turn=0;
  Future<void> getTurn() async{
    final snap = await fs.collection("games").doc("users").get();
    if(snap.exists){
      turn=snap.data()!["user${widget.user}"]["islandCount"];
    }
    setState(() {
      turn;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getTurn();
  }
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    Future<void> payment() async{
      await fs.collection("games").doc("users").update({
        "user${widget.user}.money" :FieldValue.increment(-1000000),
        "user${widget.user}.totalMoney" :FieldValue.increment(-1000000),
        "user${widget.user}.islandCount" : 0
      });
    }


    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: size.width * 0.9,
        height: size.height * 0.75,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F6F1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF8D6E63),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            /// 헤더
            Container(
              height: 64,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF3E4A59),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                "🏝 무인도",
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFFFE082),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            /// 본문
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                        height: 1.4,
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

            /// 버튼 영역 (양옆 배치)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                children: [
                  /// 💡 [수정] 구조 비용 (100만원 지불)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await payment();
                        if(mounted) {
                          // 💡 여기서 true를 반환해야 GameMain이 "돈 냈다"고 인식함
                          Navigator.pop(context, true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D6E63),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "100만원 지불",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  /// 💡 [수정] 주사위 굴리기 (그냥 닫기)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // 💡 false 반환 (돈 안 내고 더블 도전하겠다는 뜻)
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(
                          color: Color(0xFF5D4037),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "주사위 굴리기",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5D4037),
                        ),
                      ),
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