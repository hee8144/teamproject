import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BankruptDialog extends StatefulWidget {
  final int lackMoney;
  final String reason; // "tax", "toll"
  final int user;

  const BankruptDialog({
    super.key,
    required this.lackMoney,
    required this.reason,
    required this.user,
  });

  @override
  State<BankruptDialog> createState() => _BankruptDialogState();
}

class _BankruptDialogState extends State<BankruptDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  bool isAssetMode = false;

  /// 🔥 자산 리스트
  List<Map<String, dynamic>> assets = [];
  Map<String, dynamic> boardData = {};

  /// 선택된 자산 index
  final Set<int> selectedIndexes = {};

  int collectedMoney = 0;

  String get reasonTitle {
    switch (widget.reason) {
      case "tax":
        return "세금을 납부할 수 없습니다";
      case "toll":
        return "통행료를 지불할 수 없습니다";
      default:
        return "지불할 수 없습니다";
    }
  }

  Future<void> bankruptcy() async {
    final boardRef = fs.collection("games").doc("board");
    final usersRef = fs.collection("games").doc("users");

    final boardSnap = await boardRef.get();
    if (!boardSnap.exists) return;

    final batch = fs.batch();
    final boardData = boardSnap.data()!;

    batch.update(usersRef, {
      "user${widget.user}.type": "D",
    });

    boardData.forEach((key, value) {
      if (value is Map && value["owner"] == widget.user) {
        batch.update(boardRef, {
          "$key.owner": "N",
          "$key.level": 0,
          "$key.multiply": 1,
          "$key.isFestival": false,
        });
      }
    });

    await batch.commit();
  }


  Future<void> boardGet() async {
    final boardSnap = await fs.collection("games").doc("board").get();
    final List<Map<String, dynamic>> temp = [];

    if (boardSnap.exists) {
      boardData = boardSnap.data()!;
      boardData.forEach((key, value) {
        if (value is Map && value["owner"] == widget.user) {
          temp.add({
            "boardKey": key,           // b13
            "index": value["index"],
            "name": value["name"],
            "tollPrice": value["tollPrice"],
          });
        }
      });
    }

    setState(() {
      assets = temp;
      selectedIndexes.clear();
      collectedMoney = 0;
    });
  }


  Future<void> updateBoardAfterSell() async {
    Map<String, dynamic> updateData = {};

    for (int idx in selectedIndexes) {
      final asset = assets[idx];
      updateData["${asset["boardKey"]}.owner"] = 'N';
      updateData["${asset["boardKey"]}.level"] = 0;
    }

    await fs.collection("games").doc("board").update(updateData);
    await fs.collection("games").doc("users").update({
      "user1.money": FieldValue.increment(collectedMoney),
      "user1.totalMoney": FieldValue.increment(collectedMoney),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 520,
        height: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 6),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              _bankruptChoiceView(),
        ),
      ),
    );
  }

  Widget _bankruptChoiceView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_rounded, size: 60, color: Colors.red),
        const SizedBox(height: 12),

        const Text(
          "파산 위기!",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          "$reasonTitle\n부족 금액: ${widget.lackMoney} 원",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 30),

        Row(
          children: [
            _choiceButton(
              label: "즉시 파산",
              color: Colors.red,
              onTap: () async {
                await bankruptcy();
                Navigator.pop(context, {
                  "result": "BANKRUPT",
                  "reason": widget.reason,
                });
              },
            ),
            const SizedBox(width: 16),
            _choiceButton(
              label: "자산 정리",
              color: Colors.blueGrey,
              onTap: () async {
                await boardGet();
                setState(() => isAssetMode = true);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _choiceButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

}
