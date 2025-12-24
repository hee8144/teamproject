import 'package:flutter/material.dart';
import 'quiz_question.dart';
import 'dart:async';


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

class _QuizDialogState extends State<QuizDialog> {
  int remainingSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds <= 1) {
        t.cancel();
        Navigator.pop(context);
        widget.onQuizFinished(-1, false); // 시간초과 = 오답(-1은 미선택)
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height > size.width;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width * 0.9,
                maxHeight: size.height * 0.81,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8ED),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFF4A261),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    _title(),
                    const SizedBox(height: 12),
                    Text(
                      "남은 시간: $remainingSeconds초",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: isPortrait
                            ? _portraitLayout(context)
                            : _landscapeLayout(context),
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

  Widget _title() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          widget.question.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _portraitLayout(BuildContext context) {
    return Column(
      children: [
        _imageBox(height: 140),
        const SizedBox(height: 12),
        _questionAndChoices(context),
      ],
    );
  }

  Widget _landscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _imageBox()),
        const SizedBox(width: 12),
        Expanded(child: _questionAndChoices(context)),
      ],
    );
  }

  Widget _imageBox({double? height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 56, color: Colors.black45),
      ),
    );
  }

  Widget _questionAndChoices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _question(),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.8,
          children: List.generate(
            widget.question.choices.length,
                (index) => _choice(
              context,
              index,
              widget.question.choices[index],
            ),
          ),
        ),
      ],
    );
  }

  Widget _question() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.question.question,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }


  Widget _choice(BuildContext context, int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSubmitDialog(context, index, text),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF4A261)),
          ),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("제출 확인"),
        content: Text("선택한 답:\n\n$answerText\n\n제출하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              final bool isCorrect = selectedIndex == widget.question.correctIndex;
              _timer?.cancel();
              Navigator.pop(context);
              Navigator.pop(context);

              widget.onQuizFinished(selectedIndex, isCorrect);
            },
            child: const Text(
              "제출",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
