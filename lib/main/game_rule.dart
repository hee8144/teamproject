import 'package:flutter/material.dart';

class GameRulePage extends StatelessWidget {
  const GameRulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 어두운 오버레이
          Container(color: Colors.black.withOpacity(0.1)),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),

                // 중앙 규칙 패널
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF5E6).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFD7C0A1),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(27),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRuleSection(
                                title: "1. 승리 조건 (3가지)",
                                contents: [
                                  "파산 승리: 모든 상대방의 마블(돈)을 0으로 만들어 파산시키면 승리.",
                                  "트리플 독점 (Triple Victory): 서로 다른 색깔의 지역 3곳을 모두 내 땅으로 만들면 즉시 승리",
                                  "라인 독점 (Line Victory): 보드의 4면 중 한 면에 있는 모든 도시를 소유하면 즉시 승리.",
                                ],
                              ),

                              _buildRuleSection(
                                title: "2. 기본 진행 방법",
                                contents: [
                                  "주사위 굴리기: 주사위 두 개의 합만큼 이동합니다. (더블이 나오면 한 번 더 굴릴 수 있습니다. 단, 3회 연속 더블 시 무인도로 갇힘)",
                                  "건설: 빈 땅에 도착하면 건물을 짓습니다. 처음에는 건물을 1단만 지을수 있고 한바퀴를 돌때마다 내가 한번에 지을수 있는 건물의 개수가 늘어납니다. 1단 -> 2단 -> 3단 순",
                                  "랜드마크: 내가 3단으로 건물을 지은 땅에 도착하면  **'랜드마크'**를 건설할 수 있습니다. (중요: 랜드마크는 상대방이 인수(뺏기)할 수 없는 절대적인 땅이 됩니다.)",
                                  "통행료: 상대방 땅에 도착하면 통행료를 내야 합니다. 건물이 많고 비쌀수록, 랜드마크일수록 통행료가 비쌉니다.",
                                  "월급: 한바퀴 돌때마다 일정량의 돈을 줍니다.",
                                ],
                              ),

                              _buildRuleSection(
                                title: "3. 핵심 전략: 인수(Takeover)",
                                contents: [
                                  "문화재 마블을 역동적으로 만드는 가장 중요한 규칙입니다.",
                                  "인수란? 상대방의 땅에 도착했을 때, 통행료를 내고 추가 비용(건설비의 2배)을 지불하면 그 땅을 내 것으로 뺏어올 수 있습니다.",
                                  "인수 후에는 건물을 더 높게 올릴 수 있어 랜드마크 건설의 발판이 됩니다.",
                                  "단, 상대방이 이미 랜드마크를 지어버린 땅은 인수할 수 없습니다.",
                                ],
                              ),

                              _buildRuleSection(
                                title: "4. 특수 블록 설명",
                                contents: [
                                  "출발지: 도착하거나 지나갈 때마다 월급을 받습니다. 여기서 내 땅에 건물을 추가로 건설할 수도 있습니다.",
                                  "무인도/감옥: 3턴 동안 갇힙니다. (더블이 나오거나, 비용을 지불하거나, 탈출 카드를 쓰면 즉시 탈출)",
                                  "올림픽/개최지: 내 땅의 통행료를 배로 늘릴 수 있습니다.",
                                  "세계여행: 다음 턴에 원하는 곳으로 즉시 이동할 수 있습니다. (전략적으로 가장 중요한 블록)",
                                  "포춘카드(찬스): 좋은 효과(강제 이동, 도시 기부 등)나 나쁜 효과(도시 체인지, 정전 등)가 랜덤으로 발동됩니다",
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================
  // 상단 헤더
  // =============================
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 뒤로가기
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDF5E6).withOpacity(0.9),
                border: Border.all(
                  color: const Color(0xFFD7C0A1),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF5D4037),
              ),
            ),
          ),

          // 제목
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF5E6).withOpacity(0.9),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: const Color(0xFFD7C0A1),
                width: 2.5,
              ),
            ),
            child: const Text(
              "게 임 규 칙",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
                letterSpacing: 2,
              ),
            ),
          ),

          // 좌우 균형용
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // =============================
  // 규칙 섹션 (방법 3 핵심)
  // =============================
  Widget _buildRuleSection({
    required String title,
    required List<String> contents,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFFE6AD5C),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.only(left: 30, bottom: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contents.map((text) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "• $text",
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8D6E63),
                    height: 1.6,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Divider(
          color: const Color(0xFFD7C0A1).withOpacity(0.5),
          thickness: 1,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
