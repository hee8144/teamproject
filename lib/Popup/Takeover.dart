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

    takeoverCost = tollPrice * builtLevel * 2;

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
      return const Center(child: CircularProgressIndicator());
    }

    final canBuy = userMoney >= takeoverCost;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC0A060), width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const SizedBox(height: 16),

            _infoText("보유 금액", userMoney),
            _infoText("인수 비용", takeoverCost),
            _infoText("인수 후 잔액", userMoney - takeoverCost),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: canBuy
                      ? () async {
                    await _payment();
                    Navigator.pop(context,{});
                    WidgetsBinding.instance.addPostFrameCallback((_){
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ConstructionDialog(
                          buildingId: widget.buildingId,
                          user: widget.user,
                        ),
                      );
                    });
                  }
                      : null,
                  child: Text("인수 (${formatMoney(takeoverCost)})"),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소"),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFBC58B1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Center(
        child: Text(
          "건물 인수",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _infoText(String title, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        "$title : ${formatMoney(value)}",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
