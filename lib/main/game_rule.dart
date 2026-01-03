import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart';

class GameRulePage extends StatefulWidget {
  const GameRulePage({super.key});

  @override
  State<GameRulePage> createState() => _GameRulePageState();
}

class _GameRulePageState extends State<GameRulePage> {
  final CarouselSliderController _controller = CarouselSliderController();
  int _currentIndex = 0;

  // 현재 열려있는 툴팁 인덱스
  int? _openedTooltipIndex;

  final List<_RuleData> rules = [
    _RuleData(
      imagePath: 'assets/rules/game_rule.png',
      tooltip: '기본 게임 진행 규칙을 설명합니다',
      iconTop: 16.0,
      iconRight: 16.0,
      tooltipTopRatio: 0.1,
      tooltipLeftRatio: 0.05,
    ),
    _RuleData(
      imagePath: 'assets/rules/game_rule2.png',
      tooltip: '승리 조건과 특수 상황을 확인하세요',
      iconTop: 100.0,
      iconRight: 50.0,
      tooltipTopRatio: 0.7,
      tooltipLeftRatio: 0.5,
    ),
    _RuleData(
      imagePath: 'assets/rules/take_over.png',
      tooltip: '상대 땅을 인수하는 핵심 전략',
      iconTop: 60.0,
      iconRight: 30.0,
      tooltipTopRatio: 0.4,
      tooltipLeftRatio: 0.1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 + 오버레이
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              image: const DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDF5E6).withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/main'),
                          child: const Icon(Icons.arrow_back, size: 36),
                        ),
                        const Spacer(),
                        _buildDotIndicator(),
                      ],
                    ),
                  ),

                  // ===== Carousel =====
                  Expanded(
                    child: CarouselSlider(
                      carouselController: _controller,
                      options: CarouselOptions(
                        height: double.infinity,
                        enableInfiniteScroll: false,
                        viewportFraction: 1.0,
                        onPageChanged: (index, _) {
                          setState(() {
                            _currentIndex = index;
                            _openedTooltipIndex = null;
                          });
                        },
                      ),
                      items: rules.asMap().entries.map((entry) {
                        final index = entry.key;
                        final rule = entry.value;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 36 / 16,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      // ===== 이미지 =====
                                      Positioned.fill(
                                        child: Image.asset(
                                          rule.imagePath,
                                          fit: BoxFit.cover,
                                        ),
                                      ),

                                      // ===== i 아이콘 =====
                                      Positioned(
                                        top: rule.iconTop,
                                        right: rule.iconRight,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _openedTooltipIndex =
                                              _openedTooltipIndex == index
                                                  ? null
                                                  : index;
                                            });
                                          },
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.info_outline,
                                              size: 24,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ===== 툴팁 =====
                                      if (_openedTooltipIndex == index)
                                        Positioned(
                                          top: constraints.maxHeight *
                                              rule.tooltipTopRatio,
                                          left: constraints.maxWidth *
                                              rule.tooltipLeftRatio,
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 300,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 18,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2E3A59),
                                              borderRadius:
                                              BorderRadius.circular(16),
                                              border: Border.all(
                                                color: const Color(0xFFE6AD5C),
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.35),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              rule.tooltip,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator() {
    return Row(
      children: List.generate(rules.length, (index) {
        final isActive = _currentIndex == index;
        return GestureDetector(
          onTap: () => _controller.animateToPage(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color:
              isActive ? const Color(0xFFE6AD5C) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFFE6AD5C) : Colors.black,
                width: 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _RuleData {
  final String imagePath;
  final String tooltip;

  // i 아이콘 위치
  final double iconTop;
  final double iconRight;

  // 툴팁 위치 (비율로 저장: 0.0 ~ 1.0)
  final double tooltipTopRatio;
  final double tooltipLeftRatio;

  _RuleData({
    required this.imagePath,
    required this.tooltip,
    required this.iconTop,
    required this.iconRight,
    required this.tooltipTopRatio,
    required this.tooltipLeftRatio,
  });
}