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

  final List<_RuleData> rules = [
    _RuleData(imagePath: 'assets/rules/game_rule1.png'),
    _RuleData(imagePath: 'assets/rules/game_rule2.png'),
    _RuleData(imagePath: 'assets/rules/take_over.png'),
    // 필요하면 다른 이미지 추가 가능
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 배경
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
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF5E6).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFFD7C0A1),
                    width: 0,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 0),

                    // 뒤로가기 + 점 인디케이터
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

                    // Carousel
                    Expanded(
                      child: CarouselSlider(
                        carouselController: _controller,
                        options: CarouselOptions(
                          height: double.infinity,
                          enableInfiniteScroll: false,
                          viewportFraction: 1.0,
                          enlargeCenterPage: false,
                          onPageChanged: (index, _) {
                            setState(() => _currentIndex = index);
                          },
                        ),
                        items: rules.map((rule) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Center(
                                    child: AspectRatio(
                                      // 원본 이미지 비율을 사용하면 좋지만, 고정 비율(16/9)도 가능
                                      aspectRatio: 36 / 16,
                                      child: FittedBox(
                                        fit: BoxFit.cover, // 가로 꽉, 세로 비율 유지
                                        child: Image.asset(rule.imagePath),
                                      ),
                                    ),
                                  );
                                },
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
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
              color: isActive
                  ? const Color(0xFFE6AD5C)
                  : Colors.transparent,
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
  _RuleData({required this.imagePath});
}
