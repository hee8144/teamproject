import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CardUseDialog extends StatefulWidget {
  final int user;
  const CardUseDialog({super.key, required this.user});

  @override
  State<CardUseDialog> createState() => _CardUseDialogState();
}

class _CardUseDialogState extends State<CardUseDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  String Card = "N";
  bool isLoading = true;
  Future<void> getCard() async {
    final snap = await fs.collection("games").doc("users").get();
    if (snap.exists) {
      setState(() {
        Card = snap.data()!["user${widget.user}"]["card"];
        isLoading = false;
      });
    }
  }

  String get titleText {
    switch (Card) {
      case "shield":
        return "vip 명찰";
      case "escape":
        return "무인도 탈출";
      default:
        return "";
    }
  }

  String get descriptionText {
    switch (Card) {
      case "shield":
        return "vip의 특권으로 통행료를 한번 면제할수 있습니다!";
      case "escape":
        return "무인도를 즉시 탈출할수 있습니다!";
      default:
        return "현재 사용 가능한 카드가 없습니다.";
    }
  }

  Future<void> userCard() async{
    if(Card =="shield"){
      await fs.collection("games").doc("users").update(
          {
            "user${widget.user}.card":"N"
          }
      );
    }else if(Card =="escape"){
      await fs.collection("games").doc("users").update(
          {
            "user${widget.user}.card":"N",
            "user${widget.user}.islandCount":0
          }
      );
    }


  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCard();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery
        .of(context)
        .size;

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

            /// ================= 헤더 =================
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
                "카드 사용",
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFFFE082),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /// ================= 본문 =================
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      descriptionText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            /// ================= 버튼 영역 =================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                children: [

                  /// 사용하기 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await userCard();

                        if (!mounted) return;

                        if (Card == "shield") {
                          Navigator.pop(context, true);
                        } else if (Card == "escape") {
                          Navigator.pop(context, false);
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
                        "사용하기",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 취소 버튼
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
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
                        "취소",
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