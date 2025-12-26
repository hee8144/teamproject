import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class GameRulePage extends StatefulWidget {
  const GameRulePage({super.key});

  @override
  State<GameRulePage> createState() => _GameRulePageState();
}

class _GameRulePageState extends State<GameRulePage> {
  final CarouselSliderController _controller = CarouselSliderController();
  int _currentIndex = 0;

  final List<_RuleData> rules = [
    _RuleData(
      title: "1. 승리 조건 (3가지)",
      contents: [
        "파산 승리: 모든 상대방의 마블(돈)을 0으로 만들어 파산시키면 승리.",
        "트리플 독점 (Triple Victory): 서로 다른 색깔의 지역 3곳을 모두 내 땅으로 만들면 즉시 승리",
        "라인 독점 (Line Victory): 보드의 4면 중 한 면에 있는 모든 도시를 소유하면 즉시 승리.",
      ],
    ),
    _RuleData(
      title: "2. 기본 진행 방법",
      contents: [
        "주사위 굴리기: 주사위 두 개의 합만큼 이동합니다. (더블 3회 연속 시 무인도)",
        "건설: 빈 땅에 도착하면 건물 건설 (1단 → 2단 → 3단)",
        "랜드마크: 3단 건물 후 건설 가능 (인수 불가)",
        "통행료: 상대방 땅 도착 시 지불",
        "월급: 한 바퀴마다 일정 금액 지급",
      ],
    ),
    _RuleData(
      title: "3. 핵심 전략: 인수(Takeover)",
      contents: [
        "상대 땅에 도착 시 추가 비용을 내고 땅을 빼앗는 시스템",
        "건설비의 2배를 지불해야 인수 가능",
        "랜드마크가 있는 땅은 인수 불가",
      ],
    ),
    _RuleData(
      title: "4. 특수 블록 설명",
      contents: [
        "출발지: 월급 지급 + 건설 가능",
        "무인도/감옥: 3턴 정지",
        "올림픽: 통행료 배수",
        "세계여행: 원하는 위치로 이동",
        "포춘카드: 랜덤 효과 발생",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // =============================
          // 배경
          // =============================
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

                // =============================
                // 규칙 카드 + 숫자 탭
                // =============================
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 🔶 규칙 카드
                        Container(
                          width: double.infinity,
                          height: double.infinity,
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
                          child: Padding(
                            padding: const EdgeInsets.only(top: 36),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(27),
                              child: CarouselSlider(
                                carouselController: _controller,
                                options: CarouselOptions(
                                  height: double.infinity,
                                  enableInfiniteScroll: false,
                                  viewportFraction: 0.9,
                                  enlargeCenterPage: true,
                                  onPageChanged: (index, reason) {
                                    setState(() {
                                      _currentIndex = index;
                                    });
                                  },
                                ),
                                items: rules.map((rule) {
                                  return Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: _buildRuleSlide(rule),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                        // 🔶 숫자 탭 (카드에 부착)
                        Positioned(
                          top: -18,
                          right: 30,
                          child: _buildNumberIndicator(),
                        ),
                      ],
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
  // 숫자 탭 인디케이터
  // =============================
  Widget _buildNumberIndicator() {
    return Row(
      children: List.generate(rules.length, (index) {
        final bool isActive = _currentIndex == index;

        return GestureDetector(
          onTap: () => _controller.animateToPage(index),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFE6AD5C)
                  : const Color(0xFFFDF5E6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD7C0A1),
                width: 2,
              ),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                isActive ? Colors.white : const Color(0xFF8D6E63),
              ),
            ),
          ),
        );
      }),
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
                size: 28,
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
                fontSize: 26,
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
  // 슬라이드 1장
  // =============================
  Widget _buildRuleSlide(_RuleData rule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFFE6AD5C),
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              rule.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...rule.contents.map(
              (text) => Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 34),
            child: Text(
              "• $text",
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF8D6E63),
                height: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================
// 규칙 데이터 모델
// =============================
class _RuleData {
  final String title;
  final List<String> contents;

  _RuleData({required this.title, required this.contents});
}
