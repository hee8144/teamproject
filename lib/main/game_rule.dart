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

  int? _openedTooltipIndex;

  final List<_RuleData> rules = [
    _RuleData(
      title: '1. 기본 진행 방법',
      imagePath: 'assets/rules/game_rule.png',
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '주사위 굴리기',
            '주사위 두 개의 합만큼 이동합니다.',
            '더블이 나오면 한 번 더 주사위를 굴립니다.',
            '단, 3회 연속 더블 시 무인도로 갇힙니다.',
          ],
          iconTopRatio: 0.7,
          iconRightRatio: 0.55,
          tooltipTopRatio: 0.00,
          tooltipLeftRatio: 0.50,
        ),
        _TooltipData(
          tooltipLines: [
            '플레이어 정보',
            '소지금: 현재 보유하고 있는 소지금',
            '총 자산: 소지금 + 소유 건물 가격',
            '순위: 총 자산 기준'
          ],
          iconTopRatio: 0.2,
          iconRightRatio: 0.1,
          tooltipTopRatio: 0.00,
          tooltipLeftRatio: 0.00,
        ),
      ],
    ),
    _RuleData(
      title: '1. 기본 진행 방법',
      imagePath: 'assets/rules/build.png',
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '건설',
            '빈 땅에 도착하면 건물을 짓습니다.',
            '처음에는 건물을 1단만 지을수 있습니다.',
            '한바퀴를 돌때마다 내가 한번에 지을수 있는 건물의 개수가 늘어납니다. 1단 -> 2단 -> 3단 순',
          ],
          iconTopRatio: 0.2,
          iconRightRatio: 0.35,
          tooltipTopRatio: 0.0,
          tooltipLeftRatio: 0.0,
        ),
        _TooltipData(
          tooltipLines: [
            '랜드마크',
            '내가 3단으로 건물을 지은 땅에 도착하면 랜드마크를 건설할 수 있습니다.',
            '랜드마크는 상대방이 인수(뺏기)할 수 없는 절대적인 땅이 됩니다.',
          ],
          iconTopRatio: 0.5,
          iconRightRatio: 0.4,
          tooltipTopRatio: 0.00,
          tooltipLeftRatio: 0.00,
        ),
      ],
    ),
    _RuleData(
      title: '3. 특수 블록 설명',
      imagePath: 'assets/rules/domestic_travel.png',
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '국내 여행',
            '다음 턴에 원하는 곳으로 즉시 이동할 수 있습니다. (전략적으로 가장 중요한 블록)',
          ],
          iconTopRatio: 0.1,
          iconRightRatio: 0.25,
          tooltipTopRatio: 0.4,
          tooltipLeftRatio: 0.1,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
                        final ruleIndex = entry.key;
                        final rule = entry.value;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 18 / 8,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          rule.imagePath,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        left: 20,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.55),
                                            borderRadius:
                                            BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            rule.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ...rule.tooltips.asMap().entries.map((t) {
                                        final tooltipIndex = t.key;
                                        final tooltip = t.value;
                                        final uniqueIndex =
                                            ruleIndex * 10 + tooltipIndex;

                                        return Stack(
                                          children: [
                                            Positioned(
                                              top: constraints.maxHeight *
                                                  tooltip.iconTopRatio,
                                              right: constraints.maxWidth *
                                                  tooltip.iconRightRatio,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _openedTooltipIndex =
                                                    _openedTooltipIndex ==
                                                        uniqueIndex
                                                        ? null
                                                        : uniqueIndex;
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
                                            if (_openedTooltipIndex ==
                                                uniqueIndex)
                                              Positioned(
                                                top: constraints.maxHeight *
                                                    tooltip.tooltipTopRatio,
                                                left: constraints.maxWidth *
                                                    tooltip.tooltipLeftRatio,
                                                child: _buildTooltipBox(
                                                    tooltip.tooltipLines),
                                              ),
                                          ],
                                        );
                                      }),
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

  /// ✅ UI 변경 없이 두 번째 줄부터 글머리 기호만 추가
  Widget _buildTooltipBox(List<String> lines) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3A59),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6AD5C),
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines.length, (index) {
          final text = index == 0 ? lines[index] : '• ${lines[index]}';
          return Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          );
        }),
      ),
    );
  }

  Widget _buildDotIndicator() {
    return Row(
      children: List.generate(rules.length, (index) {
        final isActive = _currentIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFE6AD5C)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? const Color(0xFFE6AD5C)
                  : Colors.black,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _RuleData {
  final String title;
  final String imagePath;
  final List<_TooltipData> tooltips;

  _RuleData({
    required this.title,
    required this.imagePath,
    required this.tooltips,
  });
}

class _TooltipData {
  final List<String> tooltipLines;
  final double iconTopRatio;
  final double iconRightRatio;
  final double tooltipTopRatio;
  final double tooltipLeftRatio;

  _TooltipData({
    required this.tooltipLines,
    required this.iconTopRatio,
    required this.iconRightRatio,
    required this.tooltipTopRatio,
    required this.tooltipLeftRatio,
  });
}
