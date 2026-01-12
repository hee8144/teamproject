import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BankruptDialog extends StatefulWidget {
  final int lackMoney; // 현재 부족한 금액 (양수값)
  final String reason; // "tax", "toll"
  final int user;
  final Map<String, dynamic>? gameState; // OnlineGamePage에서 전달받음

  const BankruptDialog({
    super.key,
    required this.lackMoney,
    required this.reason,
    required this.user,
    this.gameState,
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
    // [온라인 모드 처리]
    if (widget.gameState != null) {
      // 온라인일 경우 직접 DB를 수정하지 않고 상태를 반환하여 OnlineGamePage에서 소켓을 보내게 함
      Navigator.pop(context, {"result": "BANKRUPT", "reason": widget.reason});
      return;
    }

    // [로컬 모드 처리]
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
    Navigator.pop(context, {"result": "BANKRUPT", "reason": widget.reason});
  }

  /// 🏠 내 땅 목록 불러오기
  /// 🏠 내 땅 목록 불러오기 (온라인/로컬 통합 수정본)
  Future<void> boardGet() async {
    final List<Map<String, dynamic>> temp = [];
    print("DEBUG: boardGet 시작 - 내 인덱스: ${widget.user}");

    if (widget.gameState != null) {
      // 🌐 [온라인 모드]
      final boardData = widget.gameState!['board'] as Map<String, dynamic>? ?? {};
      print("DEBUG: 온라인 보드 데이터 개수: ${boardData.length}");

      boardData.forEach((key, value) {
        if (value is Map) {
          // owner가 숫자일 수도, 문자열일 수도 있으므로 양쪽 다 고려하여 비교
          final dynamic rawOwner = value["owner"];
          final String ownerStr = rawOwner?.toString() ?? "";
          final String myIndexStr = widget.user.toString();

          if (ownerStr != "0" && ownerStr == myIndexStr) {
            print("DEBUG: 내 땅 발견! -> $key (${value['name']})");

            int toll = int.tryParse(value["tollPrice"]?.toString() ?? '0') ?? 0;
            int level = int.tryParse(value["level"]?.toString() ?? '0') ?? 0;
            int tileIndex = int.tryParse(value["index"]?.toString() ?? '0') ?? 0;

            int sellPrice = 0;
            switch (level) {
              case 1: sellPrice = toll; break;
              case 2: sellPrice = toll * 3; break;
              case 3: sellPrice = toll * 7; break;
              case 4: sellPrice = toll * 15; break;
              default: sellPrice = toll; break;
            }

            temp.add({
              "boardKey": key,
              "index": tileIndex,
              "name": value["name"] ?? "이름 없음",
              "level": level,
              "sellPrice": sellPrice,
            });
          }
        }
      });
    } else {
      // 🏠 [로컬 모드] 기존 로직 유지
      final boardSnap = await fs.collection("games").doc("board").get();
      if (boardSnap.exists) {
        var boardData = boardSnap.data()!;
        boardData.forEach((key, value) {
          if (value is Map && value["owner"].toString() == widget.user.toString()) {
            int toll = value["tollPrice"] ?? 0;
            int level = value["level"] ?? 0;
            int sellPrice = (level == 4) ? toll * 15 : (level == 3 ? toll * 7 : (level == 2 ? toll * 3 : toll));

            temp.add({
              "boardKey": key,
              "index": value["index"] ?? 0,
              "name": value["name"] ?? "토지",
              "level": level,
              "sellPrice": sellPrice,
            });
          }
        });
      }
    }

    setState(() {
      assets = temp;
      selectedIndexes.clear();
      currentSelectionTotal = 0;
    });

    print("DEBUG: 최종 로드된 자산 개수: ${assets.length}");
  }

  /// 💰 선택한 자산 판매 실행
  Future<void> sellSelectedAssets() async {
    if (selectedIndexes.isEmpty) return;

    List<String> sellKeys = [];
    int totalSellPrice = 0;

    for (int idx in selectedIndexes) {
      final asset = assets[idx];
      sellKeys.add(asset["boardKey"]);
      totalSellPrice += (asset["sellPrice"] as int);
    }

    // 🌐 [온라인 모드 처리]
    if (widget.gameState != null) {
      // 온라인일 경우 결과를 들고 OnlineGamePage로 복귀
      Navigator.pop(context, {
        "result": "SELL",
        "sellKeys": sellKeys,
        "totalEarned": totalSellPrice,
      });
      return;
    }

    // 🏠 [로컬 모드 처리]
    Map<String, dynamic> boardUpdateData = {};
    for (int idx in selectedIndexes) {
      final asset = assets[idx];
      boardUpdateData["${asset["boardKey"]}.owner"] = 'N';
      boardUpdateData["${asset["boardKey"]}.level"] = 0;
      boardUpdateData["${asset["boardKey"]}.isFestival"] = false;
    }

    final batch = fs.batch();
    final boardRef = fs.collection("games").doc("board");
    final userRef = fs.collection("games").doc("users");

    batch.update(boardRef, boardUpdateData);
    batch.update(userRef, {
      "user${widget.user}.money": FieldValue.increment(totalSellPrice),
    });

    await batch.commit();

    // 상태 업데이트 및 생존 확인 로직 유지
    setState(() {
      remainingLack -= totalSellPrice;
    });

    if (remainingLack <= 0) {
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
        Navigator.pop(context, "SURVIVED");
      }
    } else {
      await boardGet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.9;
    final dialogHeight = size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5D4037), width: 6),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isAssetMode ? _assetSellingView() : _bankruptChoiceView(),
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
        color: Color(0xFFC62828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Text(
          "파 산 위 기",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _bankruptChoiceView() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 100, color: Color(0xFFC62828)),
              const SizedBox(height: 20),
              Text(
                reasonTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    const Text("부족한 금액", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Text(
                      "${formatMoney(remainingLack)} 원",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFC62828)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: "자산 정리",
                      color: const Color(0xFF2E7D32),
                      onTap: () async {
                        await boardGet();
                        setState(() => isAssetMode = true);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _actionButton(
                      label: "즉시 파산",
                      color: const Color(0xFFC62828),
                      onTap: () async {
                        await bankruptcy();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getTileColor(int index) {
    if (index < 3) return const Color(0xFFCFFFE5);
    if (index < 7) return const Color(0xFF66BB6A);
    if (index < 10) return const Color(0xFF42A5F5);
    if (index < 14) return const Color(0xFFAB47BC);
    if (index < 17) return const Color(0xFFFFEB00);
    if (index < 21) return const Color(0xFF808080);
    if (index < 24) return const Color(0xFFFF69B4);
    return const Color(0xFFEF5350);
  }

  Widget _assetSellingView() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _summaryBox("갚아야 할 돈", remainingLack, color: Colors.red),
              const SizedBox(height: 6),
              _summaryBox("매각 선택 합계", currentSelectionTotal, color: Colors.green),
              const Spacer(),
              _actionButton(
                label: "매각 실행",
                color: const Color(0xFF2E7D32),
                onTap: selectedIndexes.isNotEmpty ? () => sellSelectedAssets() : null,
              ),
              const SizedBox(height: 4),
              _actionButton(
                label: "뒤로가기",
                color: Colors.grey[700]!,
                onTap: () => setState(() {
                  isAssetMode = false;
                  selectedIndexes.clear();
                  currentSelectionTotal = 0;
                }),
                isOutline: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 7,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD7CCC8)),
            ),
            child: assets.isEmpty
                ? const Center(child: Text("매각할 수 있는 자산이 없습니다."))
                : GridView.builder(
              itemCount: assets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final asset = assets[index];
                final isSelected = selectedIndexes.contains(index);
                final tileColor = _getTileColor(asset['index'] ?? 0);

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
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 12,
                          width: double.infinity,
                          color: tileColor,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                asset['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${asset['level']}단계",
                                style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.bold),
                              ),
                              const Divider(indent: 15, endIndent: 15, height: 10),
                              Text(
                                "${formatMoney(asset['sellPrice'])}원",
                                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryBox(String title, int value, {required Color color}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              "${formatMoney(value)}원",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}