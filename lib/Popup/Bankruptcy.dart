import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BankruptDialog extends StatefulWidget {
  final int lackMoney;
  final String reason; // "tax", "toll"

  const BankruptDialog({
    super.key,
    required this.lackMoney,
    required this.reason,
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

  String get reasonEmoji {
    switch (widget.reason) {
      case "tax":
        return "🏛";
      case "toll":
        return "🚧";
      default:
        return "⚠️";
    }
  }

  Future<void> boardGet() async {
    final boardSnap = await fs.collection("games").doc("board").get();
    final List<Map<String, dynamic>> temp = [];

    if (boardSnap.exists) {
      boardData = boardSnap.data()!;
      boardData.forEach((key, value) {
        if (value is Map && value["owner"] == "1") {
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
          child: isAssetMode
              ? _assetSellView()
              : _bankruptChoiceView(),
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
          "$reasonEmoji $reasonTitle\n부족 금액: ${widget.lackMoney} 원",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 30),

        Row(
          children: [
            _choiceButton(
              label: "💀 즉시 파산",
              color: Colors.red,
              onTap: () {
                Navigator.pop(context, {
                  "result": "BANKRUPT",
                  "reason": widget.reason,
                });
              },
            ),
            const SizedBox(width: 16),
            _choiceButton(
              label: "🏠 자산 정리",
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

  Widget _assetSellView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🏠 자산 정리",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        Text(
          "회수 금액: $collectedMoney 원",
          style: const TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: assets.isEmpty
              ? const Center(child: Text("매각 가능한 자산이 없습니다"))
              : GridView.builder(
            itemCount: assets.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final asset = assets[index];
              final isSelected =
              selectedIndexes.contains(index);

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedIndexes.remove(index);
                      collectedMoney -= asset["tollPrice"] as int;
                    } else {
                      selectedIndexes.add(index);
                      collectedMoney += asset["tollPrice"] as int;
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.green
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        asset["name"],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.green.shade800
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${asset["tollPrice"]} 원",
                        style: TextStyle(
                          color: isSelected
                              ? Colors.green.shade700
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: selectedIndexes.isEmpty
                ? null
                : () async {
              await updateBoardAfterSell();
              Navigator.pop(context, {
                "result": "ASSET_DONE",
                "money": collectedMoney,
              });
            },
            child: const Text("정리 완료"),
          ),
        ),
      ],
    );
  }
}
