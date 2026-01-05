import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Construction.dart';

class TakeoverDialog extends StatefulWidget {
  final int buildingId;
  final int user;

  const TakeoverDialog({
    super.key,
    required this.buildingId,
    required this.user,
  });

  @override
  State<TakeoverDialog> createState() => _TakeoverDialogState();
}

class _TakeoverDialogState extends State<TakeoverDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int tollPrice = 0;
  int builtLevel = 0;
  int currentOwner = 0; // 💡 원주인 저장 변수 추가
  int userMoney = 0;
  int levelMulti = 0;
  late int takeoverCost;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// ================= 데이터 로드 =================
  Future<void> _loadData() async {
    await _loadBoard();
    await _loadUser();
    switch (builtLevel) {
      case 1: levelMulti = 2; break;
      case 2: levelMulti = 6; break;
      case 3: levelMulti = 14; break;
    }
    takeoverCost = tollPrice * levelMulti;

    setState(() => loading = false);
  }

  Future<void> _loadBoard() async {
    final snap = await fs.collection("games").doc("board").get();
    if (!snap.exists) return;

    final data = snap.data()!;
    data.forEach((index, value) {
      if (value is Map && value["index"] == widget.buildingId) {
        tollPrice = value["tollPrice"] ?? 0;
        builtLevel = value["level"] ?? 0;
        // 💡 원주인 정보 가져오기
        currentOwner = int.tryParse(value["owner"].toString()) ?? 0;
      }
    });

    // 랜드마크(4단계)는 인수 불가
    if (builtLevel >= 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
    }
  }

  Future<void> _loadUser() async {
    final snap = await fs.collection("games").doc("users").get();
    if (!snap.exists) return;

    userMoney = snap.data()!["user${widget.user}"]["money"] ?? 0;
  }

  /// ================= 인수 처리 (수정됨) =================
  Future<void> _payment() async {
    // 반올림된 절반 가격 (총자산 변동폭)
    int halfCost = (takeoverCost / 2).round();

    await fs.runTransaction((tx) async {
      // 1. 구매자 (나): 돈 차감, 자산 차감
      tx.update(fs.collection("games").doc("users"), {
        "user${widget.user}.money": FieldValue.increment(-takeoverCost),
        "user${widget.user}.totalMoney": FieldValue.increment(-halfCost),
      });

      // 2. 판매자 (원주인): 돈 획득, 자산 증가 (원주인이 유효한 경우에만)
      if (currentOwner > 0 && currentOwner <= 4) {
        tx.update(fs.collection("games").doc("users"), {
          "user$currentOwner.money": FieldValue.increment(takeoverCost),
          "user$currentOwner.totalMoney": FieldValue.increment(halfCost),
        });
      }

      // 3. 보드판 업데이트 (주인 변경)
      tx.update(fs.collection("games").doc("board"), {
        "b${widget.buildingId}.owner": widget.user,
      });
    });
  }

  String formatMoney(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.brown));
    }

    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.6;
    final dialogHeight = size.height * 0.8;
    final canBuy = userMoney >= takeoverCost;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogHeight),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5D4037), width: 4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),

            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF8D6E63)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2))
                          ],
                        ),
                        child: Column(
                          children: [
                            _infoRow("보유 금액", userMoney),
                            const Divider(height: 18, color: Color(0xFF8D6E63)),
                            _infoRow("인수 비용", takeoverCost, isHighlight: true),
                            const Divider(height: 18, color: Color(0xFF8D6E63)),
                            _infoRow("인수 후 잔액", userMoney - takeoverCost,
                                isWarning: (userMoney - takeoverCost) < 0),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 버튼 영역
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              label: "인수하기",
                              color: const Color(0xFF5D4037),
                              onTap: canBuy ? () async {
                                await _payment();
                                if (context.mounted) Navigator.pop(context, true);
                              } : null,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _actionButton(
                              label: "포기",
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text(
          "건 물 인 수",
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String title, int value, {bool isHighlight = false, bool isWarning = false}) {
    Color valueColor = const Color(0xFF3E2723);
    if (isHighlight) valueColor = const Color(0xFFD84315);
    if (isWarning) valueColor = Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, color: Color(0xFF5D4037), fontWeight: FontWeight.w600)),
        Text(
          "${formatMoney(value)} 원",
          style: TextStyle(
            fontSize: isHighlight ? 20 : 18,
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
          disabledBackgroundColor: Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 18)),
      );
    }

    if (isOutline) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      );
    }

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}