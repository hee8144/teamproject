import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TakeoverDialog extends StatefulWidget {
  final int buildingId;
  final int user;
  final Map<String, dynamic>? gameState; // OnlineGamePage에서 전달받음

  const TakeoverDialog({
    super.key,
    required this.buildingId,
    required this.user,
    this.gameState,
  });

  @override
  State<TakeoverDialog> createState() => _TakeoverDialogState();
}

class _TakeoverDialogState extends State<TakeoverDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int tollPrice = 0;
  int builtLevel = 0;
  int currentOwner = 0;
  int userMoney = 0;
  int levelMulti = 0;
  int takeoverCost = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// ================= 데이터 로드 (GameState 우선, Firebase 백업) =================
  Future<void> _initData() async {
    if (widget.gameState != null) {
      // 1. 소켓으로 받은 실시간 데이터가 있을 경우 즉시 세팅
      final boardData = widget.gameState!['board']['b${widget.buildingId}'];
      final userData = widget.gameState!['users']['user${widget.user}'];
      print(userData);
      print(boardData);

      if (boardData != null) {
        tollPrice = int.tryParse(boardData['tollPrice']?.toString() ?? '0') ?? 0;
        builtLevel = int.tryParse(boardData['level']?.toString() ?? '0') ?? 0;
        currentOwner = int.tryParse(boardData['owner']?.toString() ?? '0') ?? 0;
      }
      if (userData != null) {
        userMoney = int.tryParse(userData['money']?.toString() ?? '0') ?? 0;
      }
    } else {
      // 2. 만약 gameState가 없다면 직접 Firebase에서 가져옴
      await _loadBoardFromFirebase();
      await _loadUserFromFirebase();
    }

    // 랜드마크(4단계)는 인수 불가 처리
    if (builtLevel >= 4) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // 비용 계산 로직
    switch (builtLevel) {
      case 1: levelMulti = 2; break;
      case 2: levelMulti = 6; break;
      case 3: levelMulti = 14; break;
      default: levelMulti = 2;
    }
    takeoverCost = tollPrice * levelMulti;

    setState(() => loading = false);
  }

  Future<void> _loadBoardFromFirebase() async {
    final snap = await fs.collection("games").doc("board").get();
    if (!snap.exists) return;
    final data = snap.data()!['b${widget.buildingId}'];
    if (data != null) {
      tollPrice = data["tollPrice"] ?? 0;
      builtLevel = data["level"] ?? 0;
      currentOwner = int.tryParse(data["owner"].toString()) ?? 0;
    }
  }

  Future<void> _loadUserFromFirebase() async {
    final snap = await fs.collection("games").doc("users").get();
    if (!snap.exists) return;
    userMoney = snap.data()!["user${widget.user}"]["money"] ?? 0;
  }

  /// ================= 인수 처리 (Firebase 트랜잭션) =================
  Future<void> _payment() async {
    int halfCost = (takeoverCost / 2).round();

    try {
      await fs.runTransaction((tx) async {
        // 1. 구매자 (나): 돈 차감, 자산(totalMoney) 차감
        tx.update(fs.collection("games").doc("users"), {
          "user${widget.user}.money": FieldValue.increment(-takeoverCost),
          "user${widget.user}.totalMoney": FieldValue.increment(-halfCost),
        });

        // 2. 판매자 (원주인): 돈 획득, 자산 증가
        if (currentOwner > 0 && currentOwner <= 4) {
          tx.update(fs.collection("games").doc("users"), {
            "user$currentOwner.money": FieldValue.increment(takeoverCost),
            "user$currentOwner.totalMoney": FieldValue.increment(halfCost),
          });
        }

        // 3. 보드판 업데이트 (주인 변경)
        tx.update(fs.collection("games").doc("board"), {
          "b${widget.buildingId}.owner": widget.user.toString(),
        });
      });
    } catch (e) {
      print("Transaction failed: $e");
      // 필요 시 에러 알림 로직 추가
    }
  }

  String formatMoney(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.brown));
    }

    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.6;
    final canBuy = userMoney >= takeoverCost;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8D6E63)),
                    ),
                    child: Column(
                      children: [
                        _infoRow("보유 금액", userMoney),
                        const Divider(height: 20),
                        _infoRow("인수 비용", takeoverCost, isHighlight: true),
                        const Divider(height: 20),
                        _infoRow("인수 후 잔액", userMoney - takeoverCost,
                            isWarning: (userMoney - takeoverCost) < 0),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          label: "인수하기",
                          color: const Color(0xFF5D4037),
                          onTap: canBuy ? () async {
                            setState(() => loading = true); // 중복 클릭 방지
                            await _payment();
                            if (mounted) Navigator.pop(context, true);
                          } : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionButton(
                          label: "포기",
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
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text(
          "건 물 인 수",
          style: TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _infoRow(String title, int value, {bool isHighlight = false, bool isWarning = false}) {
    Color valueColor = isWarning ? Colors.red : (isHighlight ? const Color(0xFFD84315) : const Color(0xFF3E2723));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.w600)),
        Text("${formatMoney(value)} 원", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _actionButton({required String label, required Color color, required VoidCallback? onTap, bool isOutline = false}) {
    return SizedBox(
      height: 50,
      child: onTap == null
          ? ElevatedButton(onPressed: null, child: Text(label))
          : (isOutline
          ? OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(side: BorderSide(color: color, width: 2)),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)))
          : ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
    );
  }
}