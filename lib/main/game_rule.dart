import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart';
import '../auth/auth_service.dart';

class GameRulePage extends StatefulWidget {
  final String fromPage;

  const GameRulePage({
    super.key,
    this.fromPage = 'unknown',
  });

  @override
  State<GameRulePage> createState() => _GameRulePageState();
}

class _GameRulePageState extends State<GameRulePage> with SingleTickerProviderStateMixin {
  final CarouselSliderController _controller = CarouselSliderController();
  int _currentIndex = 0;
  int? _openedTooltipIndex;

  // ✅ 애니메이션 관련 변수
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _opacityAnimation;
  bool _isAnimating = false; // 현재 애니메이션 진행 중인지 여부

  final List<_RuleData> rules = [
    _RuleData(
      title: '목차',
      imagePath: '', // 목차는 이미지 없음
      tooltips: [],
      isToc: true,
      showInToc: false, // 목차에 표시 안 함
    ),
    _RuleData(
      title: '기본 진행 방법',
      imagePath: 'assets/rules/game_start_rule.png',
      showInToc: true, // 목차에 표시
      tocTitle: '기본 진행 방법', // 목차에 표시될 이름
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '주사위 굴리기',
            '주사위 두 개의 합만큼 이동합니다.',
            '더블이 나오면 한 번 더 주사위를 굴립니다.',
            '단, 3회 연속 더블 시 무인도로 갇힙니다.',
          ],
          iconTopRatio: 0.7,
          iconRightRatio: 0.57,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.00,
        ),
        _TooltipData(
          tooltipLines: [
            '플레이어 정보',
            '클릭 시 상세 정보를 보여줍니다.',
            '현금: 현재 보유하고 있는 소지금',
            '자산: 현금 + 소유 건물 가격',
            '순위: 총 자산 기준',



          ],
          iconTopRatio: 0.2,
          iconRightRatio: 0.1,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.00,
        ),
        _TooltipData(
          tooltipLines: [
            '용어 설명',
            '칸: 보드판을 이루는 28개의 칸',
            '땅: 일반적인 칸, 플레이어 또는 봇이 해당 지역에 도착했을 때 건물을 지을 수 있습니다.',
            '문화재: 그 땅 안의 고유 문화재',
            '칸 > 땅 > 문화재',
          ],
          iconTopRatio: 0.75,
          iconRightRatio: 0.25,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.00,
        ),
      ],
    ),
    _RuleData(
      title: '건설',
      imagePath: 'assets/rules/game_build.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '건설',
            '빈 땅에 도착하면 건물을 짓습니다.',
            '처음에는 건물을 1단만 지을수 있습니다.',
            '한 바퀴를 돌 때마다 내가 한 번에 지을 수 있는 건물의 개수가 늘어납니다. 1단 -> 2단 -> 3단 순',
          ],
          iconTopRatio: 0.18,
          iconRightRatio: 0.33,
          tooltipTopRatio: 0.05,
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
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.00,
        ),
      ],
    ),
    _RuleData(
      title: '통행료 & 건물 인수',
      imagePath: 'assets/rules/toll.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '통행료',
            '상대방 땅에 도착하면 통행료를 내야 합니다.',
            '건물이 많고 비쌀수록, 랜드마크일수록 통행료가 비쌉니다.',
            '상대 땅을 밟았을 때 50% 확률로 퀴즈가 발동합니다. 퀴즈를 맞히면 통행료가 50% 할인됩니다.',
          ],
          iconTopRatio: 0.15,
          iconRightRatio: 0.8,
          tooltipTopRatio: 0.1,
          tooltipLeftRatio: 0.2,
        ),
        _TooltipData(
          tooltipLines: [
            '건물 인수',
            '인수란? 상대방의 땅에 도착했을 때, 통행료를 내고 추가 비용(건설비의 2배)을 지불하면 그 땅을 내 것으로 뺏을 수 있습니다.',
            '인수 후에는 건물을 더 높게 올릴 수 있어 랜드마크 건설의 발판이 됩니다.',
            '단, 상대방이 이미 랜드마크를 건설한 땅은 인수할 수 없습니다.',
          ],
          iconTopRatio: 0.1,
          iconRightRatio: 0.32,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.0,
        ),

      ],
    ),
    _RuleData(
      title: '퀴즈',
      imagePath: 'assets/rules/quiz.png',
      showInToc: true, // 목차에 표시
      tocTitle: '퀴즈 & 문화재', // 목차에 표시될 이름
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '퀴즈',
            '찬스 카드 밟았을 때 100% 확률로 퀴즈 발동 -> 맞추면 50% 에서 70%로 이로운 효과 확률 상승',
            '상대 땅을 밟았을 때 50% 확률로 퀴즈 발동 -> 맞추면 통행료 50% 할인',
          ],
          iconTopRatio: 0.3,
          iconRightRatio: 0.5,
          tooltipTopRatio: 0.2,
          tooltipLeftRatio: 0.0,
        ),
        _TooltipData(
          tooltipLines: [
            '제한 시간',
            '퀴즈를 푸는 데는 제한시간이 있습니다.',
            '제한 시간이 지나면 답을 제출하지 못한 걸로 간주합니다.',
          ],
          iconTopRatio: 0.1,
          iconRightRatio: 0.1,
          tooltipTopRatio: 0.1,
          tooltipLeftRatio: 0.0,
        ),
      ],
    ),

    _RuleData(
      title: '문화재 상세보기1',
      imagePath: 'assets/rules/show_detail1.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '문화재 상세보기1',
            '땅을 누르면 그 땅 만의 문화재 정보를 확인할 수 있습니다.',
          ],
          iconTopRatio: 0.25,
          iconRightRatio: 0.53,
          tooltipTopRatio: 0.45,
          tooltipLeftRatio: 0.3,
        ),
        _TooltipData(
          tooltipLines: [
            '화살표 버튼',
            '화살표를 누르면 게임 상의 정보(건설 비용, 인수 비용, 통행료)를 확인할 수 있습니다.',
          ],
          iconTopRatio: 0.75,
          iconRightRatio: 0.08,
          tooltipTopRatio: 0.45,
          tooltipLeftRatio: 0.3,
        ),
      ],
    ),
    _RuleData(
      title: '문화재 상세보기2',
      imagePath: 'assets/rules/show_detail2.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '문화재 상세보기2',
            '해당 블록의 단계별 건설 비용, 통행료, 인수 비용을 확인할 수 있습니다.',
          ],
          iconTopRatio: 0.33,
          iconRightRatio: 0.62,
          tooltipTopRatio: 0.55,
          tooltipLeftRatio: 0.05,
        ),
      ],
    ),

    _RuleData(
      title: '출발지',
      imagePath: 'assets/rules/origin.png',
      showInToc: true, // 목차에 표시
      tocTitle: '특수 칸', // 목차에 표시될 이름
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '출발지',
            '출발지에 도착하거나 지나갈 때마다 월급을 받습니다.',
            '출발지에 도착할 경우, 내 땅에 건물을 추가로 건설할 수도 있습니다.',
          ],
          iconTopRatio: 0.8,
          iconRightRatio: 0.23,
          tooltipTopRatio: 0.2,
          tooltipLeftRatio: 0.1,
        ),
        _TooltipData(
          tooltipLines: [
            '하이라이트',
            '출발지에 도착할 경우, 하이라이트된 자신의 땅을 선택하면 건물을 추가로 건설할 수 있습니다.',
          ],
          iconTopRatio: 0.7,
          iconRightRatio: 0.6,
          tooltipTopRatio: 0.2,
          tooltipLeftRatio: 0.1,
        ),
      ],
    ),

    _RuleData(
      title: '찬스 카드',
      imagePath: 'assets/rules/chance.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '찬스 카드',
            '찬스 카드에 도착하면 문화재 퀴즈에 도전하게 됩니다.',
            '퀴즈를 맞히면 좋은 효과가 발동할 확률이 기본 50% 대신 70%로 바뀝니다.',
            '좋은 효과(월급 보너스, 통행료 면제 등)나 나쁜 효과(건물 파괴, 통행료 반값 등)가 확률에 따라 발동됩니다',

          ],
          iconTopRatio: 0.47,
          iconRightRatio: 0.37,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.05,
        ),
      ],
    ),
    _RuleData(
      title: '무인도',
      imagePath: 'assets/rules/uninhabited.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '무인도',
            '3턴 동안 갇힙니다. (더블이 나오거나, 비용을 지불하거나, 탈출 카드를 쓰면 즉시 탈출)',
          ],
          iconTopRatio: 0.15,
          iconRightRatio: 0.37,
          tooltipTopRatio: 0.3,
          tooltipLeftRatio: 0.1,
        ),
      ],
    ),
    _RuleData(
      title: '지역 축제',
      imagePath: 'assets/rules/festival.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '지역 축제',
            '내 땅의 통행료를 배로 늘릴 수 있습니다.',
            '하이라이트된 자신의 땅을 선택하면 해당 지역의 지역 축제를 개최할 수 있습니다.',
          ],
          iconTopRatio: 0.25,
          iconRightRatio: 0.55,
          tooltipTopRatio: 0.3,
          tooltipLeftRatio: 0.45,
        ),
      ],
    ),
    _RuleData(
      title: '국내 여행',
      imagePath: 'assets/rules/domestic_trip.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '국내 여행',
            '다음 턴에 원하는 칸으로 즉시 이동할 수 있습니다. (전략적으로 가장 중요한 블록)',
          ],
          iconTopRatio: 0.00,
          iconRightRatio: 0.25,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.2,
        ),
      ],
    ),
    _RuleData(
      title: '국세청',
      imagePath: 'assets/rules/tax.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '국세청',
            '국세청 칸에 도착하면 세금을 납부해야 합니다.',
            '가지고 있는 땅 기본 통행료의 10%를 세금으로 냅니다. 만약 땅이 없으면 아무 효과 없습니다.',
          ],
          iconTopRatio: 0.49,
          iconRightRatio: 0.14,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.3,
        ),
      ],
    ),

    _RuleData(
      title: '승리 조건(파산 승리)',
      imagePath: 'assets/rules/bankruptcy_victory.png',
      showInToc: true, // 목차에 표시
      tocTitle: '승리 조건', // 목차에 표시될 이름
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '파산 승리',
            '모든 상대방을 파산시키면 승리합니다.',
            '파산: 보유 현금이 부족하여 부동산을 매각해도 통행료, 세금 등을 지불할 수 없을 때, 파산자는 보드판에서 본인의 건물을 모두 치우고 게임에서 빠집니다.',
          ],
          iconTopRatio: 0.05,
          iconRightRatio: 0.65,
          tooltipTopRatio: 0.05,
          tooltipLeftRatio: 0.4,
        ),
      ],
    ),

    _RuleData(
      title: '승리 조건(라인 승리)',
      imagePath: 'assets/rules/line_victory.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '라인 승리',
            '보드의 4면 중 한 면에 있는 모든 땅을 소유하면 즉시 승리합니다.',
          ],
          iconTopRatio: 0.18,
          iconRightRatio: 0.8,
          tooltipTopRatio: 0.4,
          tooltipLeftRatio: 0.3,
        ),
      ],
    ),
    _RuleData(
      title: '승리 조건(트리플 승리)',
      imagePath: 'assets/rules/triple_victory.png',
      showInToc: false,
      tooltips: [
        _TooltipData(
          tooltipLines: [
            '트리플 승리',
            '서로 다른 3가지 색깔의 땅을 모두 내 땅으로 만들면 승리합니다.',
          ],
          iconTopRatio: 0.18,
          iconRightRatio: 0.8,
          tooltipTopRatio: 0.25,
          tooltipLeftRatio: 0.4,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 펄스 애니메이션 컨트롤러 설정
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // 크기 애니메이션 (1.0 -> 1.3 -> 1.0)
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    // 투명도 애니메이션 (반짝임 효과)
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.4),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.0),
        weight: 50,
      ),
    ]).animate(_pulseController);

    // 2번 반복 후 정지
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_isAnimating) {
          setState(() {
            _isAnimating = true;
          });
          _pulseController.forward(from: 0);
        } else {
          _pulseController.stop();
          setState(() {
            _isAnimating = false;
          });
        }
      }
    });

    // 첫 번째 슬라이드 애니메이션 시작 (목차는 애니메이션 없음)
    // _startSlideAnimation(); // 목차에서는 시작하지 않음
  }

  // 슬라이드 애니메이션 시작 메서드
  void _startSlideAnimation() {
    setState(() {
      _isAnimating = false;
    });
    _pulseController.forward(from: 0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('From: ${widget.fromPage}');

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
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (widget.fromPage == 'main') {
                              context.go('/main');
                            } else if (widget.fromPage == 'unknown') {
                              context.go('/onlinemain');
                            } else {
                              context.go('/main');
                            }
                          },
                          child: const Icon(Icons.arrow_back, size: 36),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Color(0xFF000000),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '아이콘을 눌러 자세한 설명을 확인하세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _buildDotIndicator(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        CarouselSlider(
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
                              // 새 슬라이드로 이동할 때 애니메이션 시작 (목차가 아닐 때만)
                              if (index > 0) {
                                _startSlideAnimation();
                              }
                            },
                          ),
                          items: rules.asMap().entries.map((entry) {
                            final ruleIndex = entry.key;
                            final rule = entry.value;

                            // 목차 슬라이드
                            if (rule.isToc) {
                              return _buildTocSlide();
                            }

                            // 일반 슬라이드
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
                                              fit: BoxFit.contain,
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
                                                borderRadius: BorderRadius.circular(12),
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
                                            final uniqueIndex = ruleIndex * 10 + tooltipIndex;

                                            return Stack(
                                              children: [
                                                Positioned(
                                                  top: constraints.maxHeight * tooltip.iconTopRatio,
                                                  right: constraints.maxWidth * tooltip.iconRightRatio,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _openedTooltipIndex =
                                                        _openedTooltipIndex == uniqueIndex
                                                            ? null
                                                            : uniqueIndex;
                                                      });
                                                    },
                                                    child: AnimatedBuilder(
                                                      animation: _pulseController,
                                                      builder: (context, child) {
                                                        // 현재 슬라이드인 경우에만 애니메이션 적용
                                                        final shouldAnimate = _currentIndex == ruleIndex;

                                                        return Transform.scale(
                                                          scale: shouldAnimate ? _pulseAnimation.value : 1.0,
                                                          child: Opacity(
                                                            opacity: shouldAnimate ? _opacityAnimation.value : 1.0,
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
                                                                boxShadow: shouldAnimate
                                                                    ? [
                                                                  BoxShadow(
                                                                    color: Colors.white.withOpacity(0.6),
                                                                    blurRadius: 8,
                                                                    spreadRadius: 2,
                                                                  ),
                                                                ]
                                                                    : [],
                                                              ),
                                                              child: const Icon(
                                                                Icons.info_outline,
                                                                size: 24,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                if (_openedTooltipIndex == uniqueIndex)
                                                  Positioned(
                                                    top: constraints.maxHeight * tooltip.tooltipTopRatio,
                                                    left: constraints.maxWidth * tooltip.tooltipLeftRatio,
                                                    child: _buildTooltipBox(tooltip.tooltipLines),
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
                        if (_currentIndex > 0)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  _controller.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_currentIndex < rules.length - 1)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  _controller.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                    size: 32,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTocSlide() {
    // showInToc가 true인 항목만 필터링
    final tocItems = rules.asMap().entries
        .where((entry) => entry.value.showInToc)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '게임 규칙 목차',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              // const SizedBox(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: tocItems.length,
                  itemBuilder: (context, index) {
                    final entry = tocItems[index];
                    final ruleIndex = entry.key; // 실제 rules 리스트의 인덱스
                    final rule = entry.value;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: InkWell(
                        onTap: () {
                          _controller.animateToPage(
                            ruleIndex,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6AD5C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE6AD5C),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE6AD5C),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  rule.tocTitle ?? rule.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0xFFE6AD5C),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipBox(List<String> lines) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 350, maxHeight: 280),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF2E3A59),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE6AD5C),
              width: 3,
            ),
          ),
          child: SingleChildScrollView(
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
          ),
        ),
        Positioned(
          top: -10,
          right: -10,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _openedTooltipIndex = null;
              });
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE6AD5C),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2E3A59),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDotIndicator() {
    return Row(
      children: List.generate(rules.length, (index) {
        final isActive = _currentIndex == index;

        return GestureDetector(
          onTap: () {
            _controller.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
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
                color: isActive
                    ? const Color(0xFFE6AD5C)
                    : Colors.black,
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
  final String title;
  final String imagePath;
  final List<_TooltipData> tooltips;
  final bool isToc;
  final bool showInToc;
  final String? tocTitle;

  _RuleData({
    required this.title,
    required this.imagePath,
    required this.tooltips,
    this.isToc = false,
    this.showInToc = false,
    this.tocTitle,
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