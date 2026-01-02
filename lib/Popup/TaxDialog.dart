import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Bankruptcy.dart';

class TaxDialog extends StatefulWidget {
  final int user;
  const TaxDialog({super.key, required this.user});

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
        if (value is Map && value["owner"] == widget.user) {
          totalTollPrice += (value["tollPrice"] as int? ?? 0);
        }
      });
    }

    if (userSnap.exists) {
      final user = userSnap.data()!["user${widget.user}"];
      userMoney = user["money"];
      tax = (totalTollPrice * 0.1).toInt();
      remainMoney = userMoney - tax;
    }
  }

  /// 세금 차감
  Future<void> _updateMoney() async {
    await fs.collection("games").doc("users").update({
      "user${widget.user}.money": FieldValue.increment(-tax),
    });
  }

  /// 금액 포맷 (1,000,000 형태)
  String formatMoney(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _readUser(),
      builder: (context, snapshot) {
        final size = MediaQuery.of(context).size;
        final dialogWidth = size.width * 0.85;
        final dialogHeight = size.height * 0.85;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFFDF5E6), // 한지 배경
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF5D4037), width: 6), // 짙은 갈색 테두리
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // [좌측] 안내 비주얼
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF8D6E63), width: 2), // 연한 갈색 테두리
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.account_balance, size: 80, color: Color(0xFF5D4037)), // 짙은 갈색 아이콘
                                const SizedBox(height: 16),
                                const Text(
                                  "보유하신 건물의\n세금을 징수합니다.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3E2723), // 아주 짙은 갈색 텍스트
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "(전체 보유 건물 가액의 10%)",
                                  style: TextStyle(fontSize: 12, color: Colors.brown),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 20), 
                        
                        // [우측] 정보 및 버튼
                        Expanded(
                          flex: 6,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF8D6E63)), // 연한 갈색 테두리
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _infoRow("현재 보유 금액", userMoney),
                                    const Divider(height: 24, color: Color(0xFF8D6E63)),
                                    _infoRow("납부할 세금", tax, isHighlight: true),
                                    const Divider(height: 24, color: Color(0xFF8D6E63)),
                                    _infoRow("납부 후 예상 잔액", remainMoney, 
                                        isWarning: remainMoney < 0),
                                  ],
                                ),
                              ),
                              
                              const Spacer(),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: _actionButton(
                                      label: "세금 납부",
                                      color: const Color(0xFF5D4037), // 짙은 갈색 버튼
                                      onTap: isPaying ? null : () async {
                                        if (userMoney < tax) {
                                          final lackMoney = tax - userMoney;
                                          Navigator.pop(context);
                                          Future.microtask(() {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (_) => BankruptDialog(
                                                lackMoney: lackMoney,
                                                reason: "tax",
                                                user: widget.user,
                                              ),
                                            );
                                          });
                                          return;
                                        }

                                        setState(() => isPaying = true);
                                        await _updateMoney();
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _actionButton(
                                      label: "닫기",
                                      color: Colors.grey[700]!,
                                      onTap: () => Navigator.pop(context),
                                      isOutline: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037), // 짙은 갈색 헤더
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text(
          "국 세 청",
          style: TextStyle(
            color: Color(0xFFFFD700), // 금색
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String title, int value, {bool isHighlight = false, bool isWarning = false}) {
    Color valueColor = const Color(0xFF3E2723);
    if (isHighlight) valueColor = const Color(0xFFD84315); // 강조는 주황/적색
    if (isWarning) valueColor = Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.w600)),
        Text(
          "${formatMoney(value)} 원",
          style: TextStyle(
            fontSize: isHighlight ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isOutline = false,
  }) {
    if (onTap == null) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    if (isOutline) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}