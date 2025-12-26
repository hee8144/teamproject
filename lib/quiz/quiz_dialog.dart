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
    final double fullHeight = size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

  // 실제 퀴즈 내용물 (레이아웃)
  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        const SizedBox(height: 8),
        _buildTimerBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // [좌측] 이미지 영역
                Expanded(
                  flex: 4,
                  child: _imageBox(),
                ),
                const SizedBox(width: 16),
                // [우측] 문제 + 선택지 영역
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _questionBox(),
                      const SizedBox(height: 16),
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

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
      ),
      child: Column(
        children: [
          const Text(
            "대한민국 문화재 퀴즈",
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.question.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, color: Color(0xFF8B0000), size: 18),
        const SizedBox(width: 6),
        Text(
          "남은 시간: $remainingSeconds초",
          style: const TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _imageBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4C4A8), width: 2),
      ),
      child: const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(Icons.account_balance_rounded,
                  size: 64, color: Color(0xFFD4C4A8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.2)),
      ),
      child: Text(
        widget.question.question,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2F2F2F),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _choicesGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 3.2,
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF5D4037), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
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