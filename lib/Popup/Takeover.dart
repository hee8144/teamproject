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
      }
    });

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

  /// ================= 인수 처리 =================
  Future<void> _payment() async {
    await fs.runTransaction((tx) async {
      tx.update(fs.collection("games").doc("users"), {
        "user${widget.user}.money": FieldValue.increment(-takeoverCost),
      });

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
      return const Center(child: CircularProgressIndicator(color: Colors.purple));
    }

    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.85;
    final dialogHeight = size.height * 0.85;
    final canBuy = userMoney >= takeoverCost;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5D4037), width: 6),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5)),
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
                    // [좌측] 비주얼 영역
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCE93D8), width: 2), // 연한 보라 테두리
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.domain_add_rounded, size: 60, color: Color(0xFF6A1B9A)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "상대방의 건물을\n인수하시겠습니까?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[900],
                                height: 1.4,
                              ),
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
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCE93D8)),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2))
                              ],
                            ),
                            child: Column(
                              children: [
                                _infoRow("보유 금액", userMoney),
                                const Divider(height: 16, color: Color(0xFFCE93D8)),
                                _infoRow("인수 비용", takeoverCost, isHighlight: true),
                                const Divider(height: 16, color: Color(0xFFCE93D8)),
                                _infoRow("인수 후 잔액", userMoney - takeoverCost, 
                                    isWarning: (userMoney - takeoverCost) < 0),
                              ],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _actionButton(
                                  label: "인수하기",
                                  color: const Color(0xFF6A1B9A),
                                  onTap: canBuy ? () async {
                                    await _payment();
                                    if (context.mounted) Navigator.pop(context, true);
                                  } : null,
                                ),
                              ),
                              const SizedBox(width: 14),
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
                  ],
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF6A1B9A),
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
    Color valueColor = Colors.black;
    if (isHighlight) valueColor = const Color(0xFF6A1B9A);
    if (isWarning) valueColor = Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
        Text(
          "${formatMoney(value)} 원",
          style: TextStyle(
            fontSize: isHighlight ? 18 : 16,
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
