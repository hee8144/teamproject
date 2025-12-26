import 'package:flutter/material.dart';

class GameRulePage extends StatelessWidget {
  const GameRulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
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

          Container(color: Colors.black.withOpacity(0.1)),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),

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
                          padding: const EdgeInsets.all(28),
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
                                  "주사위 굴리기: 주사위 두 개의 합만큼 이동합니다. (더블 3회 연속 시 무인도)",
                                  "건설: 빈 땅에 도착하면 건물 건설 (1단 → 2단 → 3단)",
                                  "랜드마크: 3단 건물 후 건설 가능 (인수 불가)",
                                  "통행료: 상대방 땅 도착 시 지불",
                                  "월급: 한 바퀴마다 일정 금액 지급",
                                ],
                              ),

                              _buildRuleSection(
                                title: "3. 핵심 전략: 인수(Takeover)",
                                contents: [
                                  "상대 땅에 도착 시 추가 비용을 내고 땅을 빼앗는 시스템",
                                  "건설비의 2배를 지불해야 인수 가능",
                                  "랜드마크가 있는 땅은 인수 불가",
                                ],
                              ),

                              _buildRuleSection(
                                title: "4. 특수 블록 설명",
                                contents: [
                                  "출발지: 월급 지급 + 건설 가능",
                                  "무인도/감옥: 3턴 정지",
                                  "올림픽: 통행료 배수",
                                  "세계여행: 원하는 위치로 이동",
                                  "포춘카드: 랜덤 효과 발생",
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
                size: 28, // 🔼
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF5E6).withOpacity(0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFD7C0A1),
                width: 2.5,
              ),
            ),
            child: const Text(
              "게 임 규 칙",
              style: TextStyle(
                fontSize: 26, // 🔼
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
                letterSpacing: 3,
              ),
            ),
          ),

          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // =============================
  // 규칙 섹션
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
              size: 26, // 🔼
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24, // 🔼
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.only(left: 34, bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contents.map((text) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "• $text",
                  style: const TextStyle(
                    fontSize: 18, // 🔼
                    color: Color(0xFF8D6E63),
                    height: 1.8,
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
        const SizedBox(height: 24),
      ],
    );
  }
}
