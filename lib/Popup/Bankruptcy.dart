import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BankruptDialog extends StatefulWidget {
  final int lackMoney; // 현재 부족한 금액 (양수값)
  final String reason; // "tax", "toll"
  final int user;

  const BankruptDialog({
    super.key,
    required this.lackMoney,
    required this.reason,
    required this.user,
  });

  @override
  State<BankruptDialog> createState() => _BankruptDialogState();
}

class _BankruptDialogState extends State<BankruptDialog> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  bool isAssetMode = false; // 자산 정리 화면 진입 여부

  /// 🔥 자산 리스트
  List<Map<String, dynamic>> assets = [];

  /// 선택된 자산의 index들 (Set으로 중복 방지)
  final Set<int> selectedIndexes = {};

  /// 현재 선택한 자산들의 총 판매액
  int currentSelectionTotal = 0;

  /// 현재 남은 부족 금액 (판매할 때마다 줄어듦)
  late int remainingLack;

  @override
  void initState() {
    super.initState();
    remainingLack = widget.lackMoney;
  }

  String get reasonTitle {
    switch (widget.reason) {
      case "tax":
        return "세금을 납부할 수 없습니다";
      case "toll":
        return "통행료를 지불할 수 없습니다";
      default:
        return "지불할 수 없습니다";
    }
  }

  String formatMoney(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
  }

  /// 💀 완전 파산 처리
  Future<void> bankruptcy() async {
    final boardRef = fs.collection("games").doc("board");
    final usersRef = fs.collection("games").doc("users");

    final boardSnap = await boardRef.get();
    if (!boardSnap.exists) return;

    final batch = fs.batch();
    final boardData = boardSnap.data()!;

    // 유저 상태 D(Dead/파산)로 변경
    batch.update(usersRef, {
      "user${widget.user}.type": "D",
    });

    // 소유 땅 초기화
    boardData.forEach((key, value) {
      if (value is Map && value["owner"] == widget.user) {
        batch.update(boardRef, {
          "$key.owner": "N",
          "$key.level": 0,
          "$key.multiply": 1,
          "$key.isFestival": false,
        });
      }
    });

    await batch.commit();
  }

  /// 🏠 내 땅 목록 불러오기
  Future<void> boardGet() async {
    final boardSnap = await fs.collection("games").doc("board").get();
    final List<Map<String, dynamic>> temp = [];

    if (boardSnap.exists) {
      var boardData = boardSnap.data()!;
      boardData.forEach((key, value) {
        if (value is Map && value["owner"] == widget.user) {

          // 1. Firebase에서 기본 tollPrice와 현재 레벨 가져오기
          int toll = value["tollPrice"] ?? 0;
          int level = value["level"] ?? 0;

          // 💡 2. [요청하신 기준 적용] 판매 금액 계산
          int sellPrice = 0;

          switch (level) {
            case 1:
              sellPrice = toll;       // 1배
              break;
            case 2:
              sellPrice = toll * 3;   // 3배
              break;
            case 3:
              sellPrice = toll * 7;   // 7배
              break;
            case 4:
              sellPrice = toll * 15;  // 15배
              break;
            default:
            // 혹시 레벨이 0이거나 데이터가 이상할 경우 기본값(1배) 처리
              sellPrice = toll;
              break;
          }

          temp.add({
            "boardKey": key,
            "index": value["index"],
            "name": value["name"],
            "level": level,
            "sellPrice": sellPrice,   // 계산된 판매 금액 저장
          });
        }
      });
    }

    setState(() {
      assets = temp;
      selectedIndexes.clear();
      currentSelectionTotal = 0;
    });
  }

  /// 💰 선택한 자산 판매 실행
  Future<void> sellSelectedAssets() async {
    if (selectedIndexes.isEmpty) return;

    Map<String, dynamic> boardUpdateData = {};
    int totalSellPrice = 0;

    // 1. 선택된 자산들 DB 업데이트 데이터 생성
    for (int idx in selectedIndexes) {
      final asset = assets[idx];
      boardUpdateData["${asset["boardKey"]}.owner"] = 'N';
      boardUpdateData["${asset["boardKey"]}.level"] = 0;
      boardUpdateData["${asset["boardKey"]}.isFestival"] = false;

      totalSellPrice += (asset["sellPrice"] as int);
    }

    // 2. DB 업데이트 (땅 초기화 및 유저 돈 증가)
    final batch = fs.batch();
    final boardRef = fs.collection("games").doc("board");
    final userRef = fs.collection("games").doc("users");

    batch.update(boardRef, boardUpdateData);
    batch.update(userRef, {
      "user${widget.user}.money": FieldValue.increment(totalSellPrice),
      "user${widget.user}.totalMoney": FieldValue.increment(totalSellPrice), // 자산 변동은 없지만 현금 확보
    });

    await batch.commit();

    // 3. 상태 업데이트 (부족 금액 차감)
    setState(() {
      remainingLack -= totalSellPrice;
    });

    // 4. 생존 여부 확인
    if (remainingLack <= 0) {
      // 빚을 다 갚음 -> 생존!
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("위기 탈출!", style: TextStyle(color: Colors.blue)),
            content: const Text("자산을 매각하여 빚을 모두 청산했습니다.\n게임을 계속 진행합니다."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("확인"),
              )
            ],
          ),
        );
        Navigator.pop(context, "SURVIVED"); // 파산 안하고 닫기
      }
    } else {
      // 아직도 빚이 남음 -> 목록 갱신해서 더 팔게 함
      await boardGet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: 550,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          // 모드에 따라 화면 전환
          child: isAssetMode ? _assetSellingView() : _bankruptChoiceView(),
        ),
      ),
    );
  }

  /// 초기 선택 화면 (파산 vs 자산정리)
  Widget _bankruptChoiceView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_rounded, size: 70, color: Colors.red),
        const SizedBox(height: 16),
        const Text("파산 위기!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 16),
        Text("$reasonTitle\n부족 금액: ${formatMoney(remainingLack)} 원",
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        Row(
          children: [
            _choiceButton(
              label: "즉시 파산",
              color: Colors.red.shade400,
              icon: Icons.outlet,
              onTap: () async {
                await bankruptcy();
                Navigator.pop(context, {"result": "BANKRUPT", "reason": widget.reason});
              },
            ),
            const SizedBox(width: 16),
            _choiceButton(
              label: "자산 정리",
              color: Colors.green.shade600,
              icon: Icons.real_estate_agent,
              onTap: () async {
                await boardGet(); // 자산 목록 로드
                setState(() => isAssetMode = true); // 모드 변경
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 자산 정리 화면 (그리드 뷰)
  Widget _assetSellingView() {
    return Column(
      children: [
        // 상단 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("보유 자산 매각", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red)),
              child: Text("부족 금액: ${formatMoney(remainingLack)}원", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const Divider(height: 20, thickness: 2),

        // 자산 목록 그리드
        Expanded(
          child: assets.isEmpty
              ? const Center(child: Text("매각할 수 있는 자산이 없습니다."))
              : GridView.builder(
            itemCount: assets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 한 줄에 3개
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final asset = assets[index];
              final isSelected = selectedIndexes.contains(index);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedIndexes.remove(index);
                      currentSelectionTotal -= (asset["sellPrice"] as int);
                    } else {
                      selectedIndexes.add(index);
                      currentSelectionTotal += (asset["sellPrice"] as int);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.amber : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    // 💡 [요청사항 적용] 선택 시 빛나는 효과 (Glow)
                    boxShadow: isSelected
                        ? [
                      BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)
                    ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 건물 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(10)),
                        child: Text("${asset['level']}단계", style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                      const SizedBox(height: 8),
                      // 지역 이름
                      Text(asset['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      // 가격
                      Text("${formatMoney(asset['sellPrice'])}원", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.amber, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // 하단 정보 및 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("선택 합계", style: TextStyle(color: Colors.grey)),
                Text("${formatMoney(currentSelectionTotal)}원", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            Row(
              children: [
                TextButton(
                    onPressed: () => setState(() {
                      isAssetMode = false;
                      selectedIndexes.clear();
                      currentSelectionTotal = 0;
                    }),
                    child: const Text("뒤로가기")
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: selectedIndexes.isNotEmpty
                      ? () => sellSelectedAssets() // 판매 로직 실행
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("선택 자산 매각", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        )
      ],
    );
  }

  Widget _choiceButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))]
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}