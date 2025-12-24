import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Bankruptcy.dart';

class TaxDialog extends StatefulWidget {
  const TaxDialog({super.key});

  @override
  State<TaxDialog> createState() => _TaxDialogState();
}

class _TaxDialogState extends State<TaxDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int totalTollPrice = 0;
  int tax = 0;
  int userMoney = 0;
  int remainMoney = 0;
  bool isPaying = false;

  Map<String, dynamic> boardData = {};

  /// 데이터 불러오기
  Future<void> _readUser() async {
    totalTollPrice = 0;

    final userSnap = await fs.collection("games").doc("users").get();
    final boardSnap = await fs.collection("games").doc("board").get();

    if (boardSnap.exists) {
      boardData = boardSnap.data()!;
      boardData.forEach((key, value) {
        if (value is Map && value["owner"] == "1") {
          totalTollPrice += (value["tollPrice"] as int? ?? 0);
        }
      });
    }

    if (userSnap.exists) {
      final user1 = userSnap.data()!["user1"];
      userMoney = user1["money"];
      tax = (totalTollPrice * 0.1).toInt();
      remainMoney = userMoney - tax;
    }
  }

  /// 세금 차감
  Future<void> _updateMoney() async {
    await fs.collection("games").doc("users").update({
      "user1.money": FieldValue.increment(-tax),
      "user1.totalMoney": FieldValue.increment(-tax),
    });
  }

  /// 금액 박스
  Widget _moneyBox(String title, int money, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: const Icon(Icons.attach_money, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          Text(
            money.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _readUser(),
      builder: (context, snapshot) {
        final size = MediaQuery.of(context).size;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: size.width * 0.7,
            height: size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  height: 70,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF607D8B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "🏛 국세청",
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 본문 스크롤
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 왼쪽 안내
                              Expanded(
                                flex: 4,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.account_balance, size: 90),
                                    SizedBox(height: 16),
                                    Text(
                                      "보유 건물의\n세금 10%를 징수합니다!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 22),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 20),

                              // 오른쪽 금액 정보
                              Expanded(
                                flex: 6,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _moneyBox("보유 금액", userMoney, Colors.blue),
                                    _moneyBox("지불 금액", tax, Colors.red),
                                    _moneyBox("납부 후 잔액", remainMoney, Colors.green),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // 버튼
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isPaying
                                      ? null
                                      : () async {
                                    if (userMoney < tax) {
                                      final lackMoney = tax - userMoney;
                                      Navigator.pop(context);
                                      Future.microtask(() {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => BankruptDialog(
                                            lackMoney: lackMoney,
                                            reason: "toll",
                                          ),
                                        );
                                      });
                                      return;
                                    }

                                    setState(() => isPaying = true);
                                    await _updateMoney();
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF607D8B),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text("지불하기", style: TextStyle(fontSize: 20)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
