import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Detail.dart';

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
      setState(() => loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }

    setState(() => loading = false);
  }

  Future<void> _loadBoard() async {
    try {
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
    } catch (e) {
      print("Board load error: $e");
    }
  }

  Future<void> _loadUser() async {
    try {
      final snap = await fs.collection("games").doc("users").get();
      if (!snap.exists) return;

      final user = snap.data()!["user${widget.user}"];
      userLevel = user["level"] ?? 0;
      userMoney = user["money"] ?? 0;
    } catch (e) {
      print("User load error: $e");
    }
  }

  bool canSelect(int index) {
    final targetLevel = index + 1;
    if (targetLevel <= builtLevel) return false;
    if (targetLevel == 4 && builtLevel < 3) return false;
    if (targetLevel > userLevel) return false;

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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }
    
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.85;
    final dialogHeight = size.height * 0.85;

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
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // [좌측] 건물 선택 아이템
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.only(top: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD7CCC8)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(4, (index) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: _buildItem(index),
                            )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD7CCC8)),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
                              ],
                            ),
                            child: Column(
                              children: [
                                _infoRow("보유 금액", userMoney),
                                const Divider(height: 16, color: Color(0xFF8D6E63)),
                                _infoRow("건설 비용", totalCost, isHighlight: true),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: _actionButton(
                              label: "구매하기",
                              color: const Color(0xFF5D4037),
                              onTap: totalCost == 0 ? null : () async {
                                final targetLevel = getTargetLevel();
                                if(targetLevel == 4){
                                  await showDialog(context: context, builder: (context)=>DetailPopup(boardNum: widget.buildingId));
                                }
                                await _payment();
                                Navigator.pop(context,{
                                  "user":widget.user,
                                  "index":widget.buildingId,
                                  "level":targetLevel
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: _actionButton(
                              label: "취소",
                              color: Colors.grey[600]!,
                              onTap: () => Navigator.pop(context),
                            ),
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
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text(
          "건 설 하 기",
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

  Widget _infoRow(String label, int value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
        Text(
          "${formatMoney(value)} 원",
          style: TextStyle(
            fontSize: isHighlight ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFFD84315) : Colors.black,
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildItem(int index) {
    final selectable = canSelect(index);
    final built = index < builtLevel;
    final selected = selectedItems[index];

    return GestureDetector(
      onTap: selectable ? () => selectUntil(index) : null,
      child: Opacity(
        opacity: built ? 0.5 : selectable ? 1 : 0.4,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: built ? Colors.grey : (selectable ? const Color(0xFF8D6E63) : Colors.red[300]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText(index),
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? const Color(0xFFD84315) : const Color(0xFF8D6E63).withOpacity(0.3),
                  width: selected ? 3 : 1.5,
                ),
                boxShadow: selected ? [
                   BoxShadow(color: const Color(0xFFD84315).withOpacity(0.4), blurRadius: 10, spreadRadius: 1)
                ] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(itemImages[index], height: 50),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(costs[index]),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? const Color(0xFFD84315) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
