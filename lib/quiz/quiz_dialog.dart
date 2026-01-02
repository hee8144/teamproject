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

class _QuizDialogState extends State<QuizDialog>
    with TickerProviderStateMixin {
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

    final double fullWidth = min(size.width - 80, 800.0);
    final double fullHeight = size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                final currentWidth = _unrollAnimation.value * fullWidth;
                return Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: currentWidth,
                      height: fullHeight,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF5E6),
                        border: const Border.symmetric(
                          vertical: BorderSide(color: Color(0xFF3E2723), width: 12),
                          horizontal: BorderSide(color: Color(0xFF5D4037), width: 4),
                        ),
                      ),
                      child: OverflowBox(
                        minWidth: fullWidth,
                        maxWidth: fullWidth,
                        minHeight: fullHeight,
                        maxHeight: fullHeight,
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                    ),
                    Positioned(
                      left: currentWidth - 12,
                      child: _buildScrollHandle(fullHeight),
                    ),
                  ]
                );
              },
              child: Container(
                width: fullWidth,
                height: fullHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF5E6),
                  border: const Border.symmetric(
                    vertical:
                    BorderSide(color: Color(0xFF3E2723), width: 12),
                    horizontal:
                    BorderSide(color: Color(0xFF5D4037), width: 4),
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: _buildContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 30, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: _imageBox()),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(flex: 4, child: _questionBox()),
                      const SizedBox(height: 10),
                      Expanded(flex: 6, child: _choicesGrid(context)),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF5D4037),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "대한민국 문화재 퀴즈",
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14,
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
                const Icon(Icons.timer_outlined,
                    color: Colors.white, size: 14),
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

  Widget _buildScrollHandle(double height) {
    return Container(
      width: 24,
      height: height + 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF3E2723),
            Color(0xFF8D6E63),
            Color(0xFF3E2723),
          ],
        ),
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
        child: widget.question.imageUrl != null &&
            widget.question.imageUrl!.isNotEmpty
            ? Image.network(
          widget.question.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Center(child: Text("이미지 없음")),
        )
            : const Center(
          child: Icon(Icons.account_balance_rounded,
              size: 48, color: Color(0xFFD4C4A8)),
        ),
      ),
    );
  }

  Widget _questionBox() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF5D4037).withOpacity(0.2)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          widget.question.question,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _choicesGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 3.4,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        widget.question.choices.length,
            (i) => _choiceButton(context, i, widget.question.choices[i]),
      ),
    );
  }

  Widget _choiceButton(BuildContext context, int index, String text) {
    return InkWell(
      onTap: () => _showSubmitDialog(context, index, text),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF5D4037), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              color: const Color(0xFF5D4037),
              alignment: Alignment.center,
              child: Text("${index + 1}",
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmitDialog(
      BuildContext context, int selectedIndex, String answerText) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("답안 제출"),
        content: Text("선택하신 답: $answerText\n\n제출하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () {
              final isCorrect =
                  selectedIndex == widget.question.correctIndex;
              _timer?.cancel();
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onQuizFinished(selectedIndex, isCorrect);
            },
            child: const Text("제출"),
          ),
        ],
      ),
    );
  }
}
