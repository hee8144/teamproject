import 'package:flutter/material.dart';
import 'quiz_question.dart';
import 'dart:async';
import 'dart:math';

class QuizDialog extends StatefulWidget {
  final QuizQuestion question;
  final void Function(int selectedIndex, bool isCorrect) onQuizFinished;

  const QuizDialog({
    super.key,
    required this.question,
    required this.onQuizFinished,
  });

  @override
  State<QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<QuizDialog> with TickerProviderStateMixin {
  int remainingSeconds = 60;
  Timer? _timer;
  
  late AnimationController _unrollController;
  late Animation<double> _unrollAnimation;

  @override
  void initState() {
    super.initState();
    
    _unrollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _unrollAnimation = CurvedAnimation(
      parent: _unrollController,
      curve: Curves.easeOutCubic,
    );
    
    _unrollController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds <= 1) {
        t.cancel();
        Navigator.pop(context);
        widget.onQuizFinished(-1, false);
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double fullWidth = min(size.width * 0.95, 800.0);
    // 높이를 조금 더 유연하게 (너무 꽉 차지 않게 85%로 조정)
    final double fullHeight = size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _unrollAnimation,
              builder: (context, child) {
                return Container(
                  width: fullWidth * _unrollAnimation.value,
                  height: fullHeight,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF5E6),
                    border: const Border.symmetric(
                      vertical: BorderSide(color: Color(0xFF3E2723), width: 12),
                      horizontal: BorderSide(color: Color(0xFF5D4037), width: 4),
                    ),
                  ),
                  clipBehavior: Clip.hardEdge, 
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: fullWidth,
                      height: fullHeight,
                      child: child,
                    ),
                  ),
                );
              },
              child: _buildContent(context),
            ),
          ),
        ],
      ),
    );
  }

  // 실제 퀴즈 내용물
  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // 1. 헤더 통합 (타이틀 + 타이머)
        _buildHeader(),
        
        Expanded(
          child: Padding(
            // 전체 패딩 축소 (16 -> 12)
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // [좌측] 이미지 영역 (40%)
                Expanded(
                  flex: 4,
                  child: _imageBox(),
                ),
                const SizedBox(width: 12),
                
                // [우측] 문제 + 선택지 영역 (60%)
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      // 2. 질문 박스 (높이 자동 조절되도록 Flexible 사용 가능성 열어둠)
                      _questionBox(),
                      
                      const SizedBox(height: 10),
                      
                      // 3. 선택지 그리드
                      Expanded(
                        child: _choicesGrid(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // [개선 1] 타이틀과 타이머를 한 줄로 통합
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "대한민국 문화재 퀴즈",
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14, // 폰트 살짝 키움
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  "$remainingSeconds초",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4C4A8), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.question.imageUrl != null &&
                widget.question.imageUrl!.isNotEmpty)
              Image.network(
                widget.question.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF5D4037),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 32, color: Colors.grey),
                        SizedBox(height: 2),
                        Text("이미지 없음",
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              )
            else
              const Center(
                child: Icon(Icons.account_balance_rounded,
                    size: 48, color: Color(0xFFD4C4A8)),
              ),
          ],
        ),
      ),
    );
  }

  // [개선 2] 질문 박스 최적화
  Widget _questionBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 패딩 축소
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.2)),
      ),
      child: SingleChildScrollView( // 혹시라도 질문이 너무 길면 스크롤 (화면 안 깨지게)
        child: Text(
          widget.question.question,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15, // 폰트 크기 16 -> 15
            fontWeight: FontWeight.w700,
            color: Color(0xFF2F2F2F),
            height: 1.3,
          ),
        ),
      ),
    );
  }

  // [개선 3] 선택지 그리드 납작하게
  Widget _choicesGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8, // 간격 축소 (12 -> 8)
      mainAxisSpacing: 8,
      childAspectRatio: 3.0, // 더 납작하게 (2.2 -> 3.0)
      children: List.generate(
        widget.question.choices.length,
        (index) => _choiceButton(
          context,
          index,
          widget.question.choices[index],
        ),
      ),
    );
  }

  Widget _choiceButton(BuildContext context, int index, String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSubmitDialog(context, index, text),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF5D4037), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28, // 번호표 너비 축소
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13, // 선택지 폰트 14 -> 13
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF424242),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmitDialog(
    BuildContext context,
    int selectedIndex,
    String answerText,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFDF5E6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF5D4037), width: 3),
        ),
        title: const Text(
          "답안 제출",
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
        ),
        content: Text(
          "선택하신 답: $answerText\n\n이대로 제출하시겠습니까?",
          style: const TextStyle(color: Color(0xFF424242)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("다시 생각하기", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final bool isCorrect =
                  selectedIndex == widget.question.correctIndex;
              _timer?.cancel();
              Navigator.pop(context); // 팝업 닫기
              Navigator.pop(context); // 퀴즈 다이얼로그 닫기

              widget.onQuizFinished(selectedIndex, isCorrect);
            },
            child: const Text("제출"),
          ),
        ],
      ),
    );
  }
}
