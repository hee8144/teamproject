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
  int userLevel = 0;
  int userMoney = 0;
  bool isMyProperty = false; // 내 땅 여부 저장 변수 추가

  List<int> costs = [];
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
    if (costs.isEmpty) return false;
    for (int i = builtLevel; i < 4; i++) {
      if (canSelect(i)) return true;
    }
    return false;
  }

  Future<void> _loadData() async {
    try {
      if (widget.gameState != null) {
        // 🌐 [온라인 모드]
        final boardMap = widget.gameState!['board'] ?? {};
        final tileData = boardMap['b${widget.buildingId}'] ?? {};

        totalTollPrice = int.tryParse(tileData['tollPrice']?.toString() ?? '0') ?? 0;
        builtLevel = int.tryParse(tileData['level']?.toString() ?? '0') ?? 0;

        // 타입 불일치 방지를 위해 toString() 비교
        final String ownerValue = tileData['owner']?.toString() ?? 'N';
        final String myIndexStr = widget.user.toString();

        if (ownerValue == myIndexStr || ownerValue == "0" || ownerValue == "N") {
          isMyProperty = true;
        } else {
          // 인수한 경우를 대비해, 그냥 true로 박아버리거나 부모로부터
          // 'isTakeover' 같은 플래그를 받아 처리하는 것이 가장 확실합니다.
          isMyProperty = true;
        }

        final userMap = widget.gameState!['users'] ?? {};
        final userData = userMap['user${widget.user}'] ?? {};
        userLevel = int.tryParse(userData['level']?.toString() ?? '1') ?? 1;
        userMoney = int.tryParse(userData['money']?.toString() ?? '0') ?? 0;
      } else {
        // 🏠 [로컬 모드]
        await _loadBoard();
        await _loadUser();
      }

      // 비용 리스트 생성
      costs = [
        totalTollPrice,
        totalTollPrice * 2,
        totalTollPrice * 3,
        totalTollPrice * 4
      ];

      if (!mounted) return;

      bool anySelectable = hasAnySelectable();

      // 내 땅이거나 지을 수 있는 건물이 있다면 팝업 유지
      if (builtLevel < 4) {
        setState(() => loading = false);
      } else {
        // 이미 랜드마크라면 더 지을 게 없으니 닫음
        Navigator.pop(context);
      }
    } catch (e) {
      print("데이터 로드 중 에러: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _loadBoard() async {
    final snap = await fs.collection("games").doc("board").get();
    if (!snap.exists) return;
    final data = snap.data()!;
    data.forEach((key, value) {
      if (value is Map && value["index"] == widget.buildingId) {
        totalTollPrice = int.tryParse(value["tollPrice"]?.toString() ?? '0') ?? 0;
        builtLevel = int.tryParse(value["level"]?.toString() ?? '0') ?? 0;
        // 로컬 모드에서도 내 땅 판정 추가 필요 시 여기에 작성
      }
    });
  }

  Future<void> _loadUser() async {
    final snap = await fs.collection("games").doc("users").get();
    if (!snap.exists) return;
    final user = snap.data()!["user${widget.user}"];
    userLevel = int.tryParse(user["level"]?.toString() ?? '1') ?? 1;
    userMoney = int.tryParse(user["money"]?.toString() ?? '0') ?? 0;
  }

  /// ================= 선택 로직 =================
  bool canSelect(int index) {
    if (costs.isEmpty) return false;
    final targetLevel = index + 1;

    if (targetLevel > userLevel) return false;
    if (targetLevel <= builtLevel) return false;
    if (targetLevel == 4 && builtLevel < 3) return false;

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

  String formatMoney(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 에러 방지 핵심: 로딩 중이거나 costs가 채워지지 않았으면 화면을 그리지 않음
    if (loading || costs.length < 4) {
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
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD7CCC8)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(4, (index) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: _buildItem(index),
                            )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                const Divider(height: 14, color: Color(0xFF8D6E63)),
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
                                if (targetLevel == 4) {
                                  await showDialog(
                                      context: context,
                                      builder: (context) => DetailPopup(boardNum: widget.buildingId));
                                }
                                Navigator.pop(context, {
                                  "level": targetLevel,
                                  "totalCost": totalCost,
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: _actionButton(
                              label: "취소",
                              color: Colors.grey[600]!,
                              onTap: () => Navigator.pop(context),
                              isOutline: true,
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
      padding: const EdgeInsets.symmetric(vertical: 16),
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
            fontSize: isHighlight ? 20 : 16,
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
    // 💡 costs 리스트가 안전하게 채워졌는지 확인 (한 번 더 방어)
    if (costs.length <= index) return const SizedBox();

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
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
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