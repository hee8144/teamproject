import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConstructionDialog extends StatefulWidget {
  final int buildingId;
  final int user;

  const ConstructionDialog({
    super.key,
    required this.buildingId,
    required this.user,
  });

  @override
  State<ConstructionDialog> createState() => _ConstructionDialogState();
}

class _ConstructionDialogState extends State<ConstructionDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  int totalTollPrice = 0;
  int builtLevel = 0;
  int userLevel = 0;
  int userMoney = 0;

  late List<int> costs = [];
  List<bool> selectedItems = [false, false, false, false];

  final List<String> itemNames = ["별장", "빌딩", "호텔", "랜드마크"];
  final List<String> itemImages = [
    "assets/blue-building1.PNG",
    "assets/blue-building2.PNG",
    "assets/blue-building3.PNG",
    "assets/landmark.png",
  ];

  int totalCost = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// ================= 데이터 로드 =================//
  bool hasAnySelectable() {
    for (int i = builtLevel; i < 4; i++) {
      if (canSelect(i)) return true;
    }
    return false;
  }

  Future<void> _loadData() async {
    await _loadBoard();
    await _loadUser();

    if (!hasAnySelectable()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }

    setState(() => loading = false);
  }

  Future<void> _loadBoard() async {
    final snap = await fs.collection("games").doc("board").get();
    if (!snap.exists) return;

    final data = snap.data()!;
    data.forEach((key, value) {
      if (value is Map && value["index"] == widget.buildingId) {
        totalTollPrice = value["tollPrice"] ?? 0;
        builtLevel = value["level"] ?? 0;
      }
    });

    if (builtLevel >= 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }

    costs = [
      totalTollPrice,
      totalTollPrice * 2,
      totalTollPrice * 3,
      totalTollPrice * 4,
    ];
  }

  Future<void> _loadUser() async {
    final snap = await fs.collection("games").doc("users").get();
    if (!snap.exists) return;

    final user = snap.data()!["user${widget.user}"];
    userLevel = user["level"] ?? 0;
    userMoney = user["money"] ?? 0;
  }

  /// ================= 선택 로직 =================
  bool canSelect(int index) {
    final targetLevel = index + 1;

    // 이미 지어진 단계는 선택 불가
    if (targetLevel <= builtLevel) return false;


    // 랜드마크는 반드시 3단계가 지어져 있어야 가능
    if (targetLevel == 4 && builtLevel < 3) return false;

    // 유저 레벨 제한
    if (targetLevel > userLevel) return false;

    // 돈 계산 (연속 단계 비용 합)
    int requiredCost = 0;
    for (int i = builtLevel; i <= index; i++) {
      requiredCost += costs[i];
    }

    if (userMoney < requiredCost) return false;

    return true;
  }

  void selectUntil(int index) {
    setState(() {
      selectedItems = [false, false, false, false];
      for (int i = builtLevel; i <= index; i++) {
        selectedItems[i] = true;
      }
      _calculateTotal();
    });
  }

  String statusText(int index) {
    if (index < builtLevel) return "이미 건설됨";
    if (index + 1 > userLevel) return "레벨 부족";

    int requiredCost = 0;
    for (int i = builtLevel; i <= index; i++) {
      requiredCost += costs[i];
    }

    if (userMoney < requiredCost) return "돈 부족";
    return "선택 가능";
  }

  /// ================= 비용 =================
  void _calculateTotal() {
    int sum = 0;
    for (int i = 0; i < selectedItems.length; i++) {
      if (selectedItems[i]) sum += costs[i];
    }
    totalCost = sum;
  }

  int getTargetLevel() {
    for (int i = selectedItems.length - 1; i >= 0; i--) {
      if (selectedItems[i]) return i + 1;
    }
    return builtLevel;
  }

  Future<void> _payment() async {
    final targetLevel = getTargetLevel();

    await fs.collection("games").doc("users").update({
      "user${widget.user}.money": FieldValue.increment(-totalCost),
    });

    await fs.collection("games").doc("board").update({
      "b${widget.buildingId}.level": targetLevel,
      "b${widget.buildingId}.owner": widget.user,
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

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 450,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC0A060), width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, _buildItem),
              ),
            ),
            Text(
              "보유 금액: ${formatMoney(userMoney)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "건설 비용 합계: ${formatMoney(totalCost)}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: totalCost == 0 ? null : () async {
                final targetLevel = getTargetLevel();
                await _payment();
                Navigator.pop(context,{
                  "user":widget.user,
                  "index":widget.buildingId,
                  "level":targetLevel
                });
              },
              child: Text("구매 (${formatMoney(totalCost)})"),
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
          "건설",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final selectable = canSelect(index);
    final built = index < builtLevel;

    return GestureDetector(
      onTap: selectable ? () => selectUntil(index) : null,
      child: Opacity(
        opacity: built ? 0.6 : selectable ? 1 : 0.35,
        child: Container(
          width: 90,
          decoration: BoxDecoration(
            color: built ? Colors.grey.shade300 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selectedItems[index]
                  ? Colors.orange
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFD2B48C),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Text(
                  statusText(index),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              Image.asset(itemImages[index], height: 45),
              const SizedBox(height: 6),
              Text(
                formatMoney(costs[index]),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: built
                      ? Colors.grey
                      : selectable
                      ? Colors.orange
                      : Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
