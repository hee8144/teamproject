import 'package:flutter/material.dart';

void main() {
  runApp(const MarbleApp());
}

class MarbleApp extends StatelessWidget {
  const MarbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GamePopupPage(),
    );
  }
}

class GamePopupPage extends StatefulWidget {
  const GamePopupPage({super.key});

  @override
  State<GamePopupPage> createState() => _GamePopupPageState();
}

class _GamePopupPageState extends State<GamePopupPage> {
  // ===== 핵심 상태 =====
  bool isMyLand = true;       // true: 내 땅 / false: 상대 땅
  bool isQuizCorrect = true; // 퀴즈 정답 여부
  int? selectedBuildLevel;   // 1,2,3단

  // ===== 더미 지역 정보 =====
  final String regionName = "인천";
  final String regionDesc =
      "서해안에 위치한 항구 도시로, 개항 이후 다양한 문화유산이 남아 있습니다.";
  final List<String> heritageTypes = ["사적", "국가문화재", "근대문화유산"];

  int buildCost(int level) {
    final base = {1: 200, 2: 400, 3: 800}[level]!;
    return isQuizCorrect ? (base * 0.5).toInt() : base;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ===== 보드 대체 배경 =====
          Container(color: const Color(0xFF2F3E34)),

          // ===== 어두운 오버레이 =====
          Container(color: Colors.black.withOpacity(0.45)),

          // ===== 중앙 팝업 =====
          SafeArea(
            child: Center(
              child: Container(
                width: size.width * 0.95,
                height: size.height * 0.80,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6C9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF4A261), width: 2),
                ),
                child: Column(
                  children: [
                    // ===== 상단 =====
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            regionName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    if (isQuizCorrect) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "퀴즈 정답 효과: 비용 50% 할인",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    Expanded(
                      child: Row(
                        children: [
                          // ===== 왼쪽: 지역 정보 =====
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "지역 정보",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    regionDesc,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    children: heritageTypes
                                        .map(
                                          (e) => Chip(
                                        label: Text(
                                          e,
                                          style:
                                          const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // ===== 오른쪽: 행동 영역 =====
                          Expanded(
                            child: isMyLand
                                ? _buildMyLandUI()
                                : _buildEnemyLandUI(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // 내 땅 UI (건설)
  // ===============================
  Widget _buildMyLandUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "건설 단계 선택",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Row(
          children: [1, 2, 3].map((level) {
            final selected = selectedBuildLevel == level;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text("$level단"),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    selectedBuildLevel = level;
                  });
                },
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: selectedBuildLevel == null
              ? const Text("건설 단계를 선택하세요")
              : Text(
            "건설 비용: ${buildCost(selectedBuildLevel!)}만",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedBuildLevel == null ? null : () {},
            child: const Text("건설"),
          ),
        ),
      ],
    );
  }

  // ===============================
  // 상대 땅 UI (통행료 / 인수)
  // ===============================
  Widget _buildEnemyLandUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "상대 땅 도착",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            child: const Text("인수"),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              // 여기서 찬스카드 보유 여부 체크 후 다이얼로그
            },
            child: const Text("통행료 지불"),
          ),
        ),
      ],
    );
  }
}
