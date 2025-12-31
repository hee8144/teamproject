import 'package:flutter/material.dart';

class RegionDetailPopup extends StatelessWidget {
  // ★ 외부에서 주입
  final bool quizEffect;

  const RegionDetailPopup({
    super.key,
    required this.quizEffect,
  });

  /// ===== 더미 상태값 =====
  final bool hasOwner = true;
  final bool isArrived = true;
  final bool isMyLand = true;
  final int buildLevel = 1; // 0~4 (4=랜드마크)

  Widget _infoOnlyPanel() {
    if (!hasOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(
            leftTitle: "소유자",
            leftValue: "없음",
            rightTitle: "땅 가격",
            rightValue: "22만",
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoCard(
          leftTitle: "소유자",
          leftValue: isMyLand ? "나" : "플레이어 2",
          rightTitle: "건설 단계",
          rightValue: buildLevelText(buildLevel),
        ),
        const SizedBox(height: 10),
        _singleInfoCard(
          title: "현재 통행료",
          value: "32만",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: size.width * 0.92,
        height: size.height * 0.90,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE6C9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "인천",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(width: 40, child: Icon(Icons.close)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: _leftInfoArea()),
                    const SizedBox(width: 10),
                    Expanded(child: _rightPanel()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftInfoArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("지역 정보", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text(
            "인천은 서해안에 위치한 항구 도시로 다양한 문화유산을 보유하고 있습니다.",
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 10),
          Text("문화재", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text("• 강화 고인돌"),
          Text("• 전등사"),
          Text("• 개항장 거리"),
        ],
      ),
    );
  }

  Widget _rightPanel() {
    if (!isArrived) return _infoOnlyPanel();
    return isMyLand ? _myLandUI() : _enemyLandUI();
  }

  String buildLevelText(int level) {
    if (level == 0) return "미건설";
    if (level == 4) return "랜드마크";
    return "${level}단";
  }

  Widget _myLandUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quizEffect)
          Container(
            padding: const EdgeInsets.all(5),
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Text(
              "퀴즈 정답 효과\n건설 비용 50% 할인",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        _infoCard(
          leftTitle: "현재 단계",
          leftValue: buildLevelText(buildLevel),
          rightTitle: "다음 단계",
          rightValue: buildLevel < 3 ? "${buildLevel + 1}단" : "랜드마크",
        ),
        const SizedBox(height: 5),
        _infoCard(
          leftTitle: "현재 통행료",
          leftValue: "88만",
          rightTitle: "건설 비용",
          rightValue: "44만",
        ),
        const Spacer(),
        Center(
          child: SizedBox(
            width: 170,
            height: 42,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text("건 설", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _enemyLandUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quizEffect)
          Container(
            padding: const EdgeInsets.all(1),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Text(
              "퀴즈 정답 효과\n통행료 50% 할인",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        _infoCard(
          leftTitle: "건설 단계",
          leftValue: buildLevelText(buildLevel),
          rightTitle: "현재 통행료",
          rightValue: "88만",
        ),
        const SizedBox(height: 5),
        _infoCard(
          leftTitle: "인수 비용",
          leftValue: "176만",
          rightTitle: "보유 금액",
          rightValue: "700만",
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text("통행료 지불"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(onPressed: () {}, child: const Text("인수")),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoCard({
    required String leftTitle,
    required String leftValue,
    required String rightTitle,
    required String rightValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _infoCell(leftTitle, leftValue),
          const SizedBox(width: 8),
          _infoCell(rightTitle, rightValue),
        ],
      ),
    );
  }

  Widget _infoCell(String title, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _singleInfoCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
