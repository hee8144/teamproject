import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IslandDialog extends StatefulWidget {
  final int user;

  const IslandDialog({
    super.key, 
    required this.user,
  });

  @override
  State<IslandDialog> createState() => _IslandDialogState();
}

class _IslandDialogState extends State<IslandDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  int turn = 0;
  bool isLoading = true;

  Future<void> _getTurnFromDB() async {
    try {
      final snap = await fs.collection("games").doc("users").get();
      if (snap.exists && mounted) {
        setState(() {
          turn = snap.data()!["user${widget.user}"]["islandCount"] ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _getTurnFromDB();
  }

  Future<void> _paymentAction() async {
    await fs.collection("games").doc("users").update({
      "user${widget.user}.money": FieldValue.increment(-1000000),
      "user${widget.user}.islandCount": 0
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.85;
    final dialogHeight = size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6), // 한지 배경
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF5D4037), width: 6), // 나무 테두리
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.brown))
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // [좌측]
                          Expanded(
                            flex: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF8D6E63), width: 2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.beach_access_rounded, size: 80, color: Color(0xFF5D4037)),
                                  const SizedBox(height: 16),
                                  Text(
                                    "무인도",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown[900],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "현재 $turn턴 남음",
                                    style: const TextStyle(fontSize: 16, color: Color(0xFFD84315), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 20),

                          // [우측]
                          Expanded(
                            flex: 6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF8D6E63)),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
                                    ],
                                  ),
                                  child: const Column(
                                    children: [
                                      Text(
                                        "💰 구조 비용 100만원 지불 시\n즉시 탈출이 가능합니다.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.w600),
                                      ),
                                      Divider(height: 26, color: Color(0xFFEFEBE9)),
                                      Text(
                                        "• 더블이 나오면 무료 탈출\n• 모든 턴 경과 시 자동 탈출",
                                        textAlign: TextAlign.left,
                                        style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF5D4037)),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: _actionButton(
                                        label: "100만원 지불",
                                        color: const Color(0xFF5D4037),
                                        onTap: () async {
                                          await _paymentAction();
                                          if (mounted) Navigator.pop(context, true);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _actionButton(
                                        label: "주사위 굴리기",
                                        color: Colors.grey[700]!,
                                        onTap: () => Navigator.pop(context, false),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text(
          "무 인 도",
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isOutline = false,
  }) {
    if (isOutline) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 10),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
