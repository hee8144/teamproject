// ⚠️ import 동일
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Detail.dart';

class ConstructionDialog extends StatefulWidget {
  final int buildingId;
  final int user;
  final Map<String, dynamic>? gameState;

  const ConstructionDialog({
    super.key,
    required this.buildingId,
    required this.user,
    this.gameState,
  });

  @override
  State<ConstructionDialog> createState() => _ConstructionDialogState();
}

class _ConstructionDialogState extends State<ConstructionDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int totalTollPrice = 0;
  int builtLevel = 0;
  int userLevel = 1;
  int userMoney = 0;
  bool isMyProperty = false;

  List<int> costs = [];
  List<bool> selectedItems = [false, false, false, false];
  int totalCost = 0;
  bool loading = true;

  final List<String> itemImages = [
    "assets/blue-building1.PNG",
    "assets/blue-building2.PNG",
    "assets/blue-building3.PNG",
    "assets/landmark.png",
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /* ================= 데이터 ================= */

  Future<void> _loadData() async {
    if (widget.gameState != null) {
      _loadFromOnline();
    } else {
      await _loadBoardLocal();
      await _loadUserLocal();
    }

    costs = [
      totalTollPrice,
      totalTollPrice * 2,
      totalTollPrice * 3,
      totalTollPrice * 4,
    ];

    if (!mounted) return;
    if (builtLevel >= 4) {
      Navigator.pop(context);
      return;
    }

    setState(() => loading = false);
  }

  void _loadFromOnline() {
    final board =
        widget.gameState!['board']?['b${widget.buildingId}'] ?? {};
    final user =
        widget.gameState!['users']?['user${widget.user}'] ?? {};

    totalTollPrice = int.tryParse(board['tollPrice']?.toString() ?? '0') ?? 0;
    builtLevel = int.tryParse(board['level']?.toString() ?? '0') ?? 0;

    final owner = board['owner']?.toString() ?? 'N';
    isMyProperty =
        owner == widget.user.toString() || owner == '0' || owner == 'N';

    userLevel = int.tryParse(user['level']?.toString() ?? '1') ?? 1;
    userMoney = int.tryParse(user['money']?.toString() ?? '0') ?? 0;
  }

  Future<void> _loadBoardLocal() async {
    final snap = await fs.collection("games").doc("board").get();
    snap.data()?.forEach((_, v) {
      if (v is Map && v['index'] == widget.buildingId) {
        totalTollPrice = v['tollPrice'];
        builtLevel = v['level'];
        isMyProperty = true;
      }
    });
  }

  Future<void> _loadUserLocal() async {
    final snap = await fs.collection("games").doc("users").get();
    final user = snap.data()!['user${widget.user}'];
    userLevel = user['level'];
    userMoney = user['money'];
  }

  /* ================= 선택 ================= */

  bool canSelect(int index) {
    if (!isMyProperty) return false;
    if (index + 1 > userLevel) return false;
    if (index < builtLevel) return false;
    if (index == 3 && builtLevel < 3) return false;

    int sum = 0;
    for (int i = builtLevel; i <= index; i++) {
      sum += costs[i];
    }
    return userMoney >= sum;
  }

  void selectUntil(int index) {
    setState(() {
      selectedItems = [false, false, false, false];
      for (int i = builtLevel; i <= index; i++) {
        selectedItems[i] = true;
      }
      totalCost = selectedItems
          .asMap()
          .entries
          .where((e) => e.value)
          .fold(0, (s, e) => s + costs[e.key]);
    });
  }

  int getTargetLevel() {
    for (int i = 3; i >= 0; i--) {
      if (selectedItems[i]) return i + 1;
    }
    return builtLevel;
  }

  String formatMoney(int v) =>
      v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      backgroundColor: const Color(0xFFF9F1E6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 900,
        height: 520,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    /// ===== LEFT =====
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF7ED),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: List.generate(
                            4,
                                (i) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _buildItem(i),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 18),

                    /// ===== RIGHT =====
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                _infoRow("보유 금액", userMoney),
                                const Divider(height: 18),
                                _infoRow("건설 비용", totalCost,
                                    highlight: true),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: totalCost == 0
                                  ? null
                                  : () async {
                                final level = getTargetLevel();
                                if (level == 4) {
                                  await showDialog(
                                    context: context,
                                    builder: (_) => DetailPopup(
                                        boardNum: widget.buildingId),
                                  );
                                }
                                Navigator.pop(context, {
                                  "level": level,
                                  "totalCost": totalCost,
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color(0xFF6B4B3E),
                                disabledBackgroundColor:
                                const Color(0xFFCFC3B5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "구매하기",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("취소"),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  /* ================= Components ================= */

  Widget _header() => Container(
    height: 56,
    decoration: const BoxDecoration(
      color: Color(0xFF6B4B3E),
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    alignment: Alignment.center,
    child: const Text(
      "건설하기",
      style: TextStyle(
          color: Color(0xFFFFD400),
          fontSize: 20,
          fontWeight: FontWeight.bold),
    ),
  );

  Widget _infoRow(String label, int value, {bool highlight = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label),
      Text(
        "${formatMoney(value)} 원",
        style: TextStyle(
          fontSize: highlight ? 18 : 16,
          fontWeight: FontWeight.bold,
          color: highlight
              ? const Color(0xFFFF6A00)
              : Colors.black,
        ),
      ),
    ],
  );

  Widget _buildItem(int index) {
    final built = index < builtLevel;
    final selectable = canSelect(index);
    final selected = selectedItems[index];

    return GestureDetector(
      onTap: selectable ? () => selectUntil(index) : null,
      child: Stack(
        children: [
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFF6A00)
                    : const Color(0xFFE0D6C8),
                width: selected ? 3 : 1,
              ),
            ),
            child: Column(
              children: [
                Opacity(
                  opacity: built || !selectable ? 0.35 : 1,
                  child: Image.asset(
                    itemImages[index],
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${formatMoney(costs[index])} 원",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: built || !selectable
                        ? Colors.grey
                        : const Color(0xFFFF6A00),
                  ),
                ),
              ],
            ),
          ),

          /// ===== Badge =====
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selectable
                      ? const Color(0xFF6B4B3E)
                      : const Color(0xFFF1B7B7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selectable ? "선택 가능" : "레벨 부족",
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
