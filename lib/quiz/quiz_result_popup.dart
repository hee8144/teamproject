import 'package:flutter/material.dart';
import 'quiz_question.dart';

class QuizResultPopup extends StatefulWidget {
  final QuizQuestion question;
  final int selectedIndex; // -1이면 시간초과
  final bool isCorrect;

  const QuizResultPopup({
    super.key,
    required this.question,
    required this.selectedIndex,
    required this.isCorrect,
  });

  @override
  State<QuizResultPopup> createState() => _QuizResultPopupState();
}

class _QuizResultPopupState extends State<QuizResultPopup> {
  int? explanationIndex;

  @override
  Widget build(BuildContext context) {
    final bool isTimeout = widget.selectedIndex == -1;
    final int userSelectedIndex = widget.selectedIndex;

    final int correctIndex = widget.question.correctIndex;
    final List<String> answers = widget.question.choices;
    final List<String> explanations = widget.question.explanations;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            children: [
              // ===== 상단 =====
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        isTimeout
                            ? "시간 초과!"
                            : (widget.isCorrect ? "정답입니다!" : "오답입니다!"),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isTimeout
                              ? Colors.orange
                              : (widget.isCorrect
                              ? Colors.green
                              : Colors.red),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ===== 좌 / 우 =====
              Expanded(
                child: Row(
                  children: [
                    // ---- 좌: 선택지(2x2) ----
                    Expanded(
                      flex: 2,
                      child: GridView.builder(
                        itemCount: 4,
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemBuilder: (context, index) {
                          final bool isCorrectCard = index == correctIndex;
                          final bool isUserCard =
                              !isTimeout && index == userSelectedIndex;

                          Color bgColor = Colors.white;
                          Color borderColor = Colors.grey;

                          if (isCorrectCard) {
                            bgColor = const Color(0xFFE0F2F1);
                            borderColor = Colors.green;
                          } else if (isUserCard) {
                            borderColor = Colors.red;
                          }

                          return InkWell(
                            onTap: () {
                              // 시간초과여도 해설은 보여줌
                              if (!isCorrectCard) {
                                setState(() {
                                  explanationIndex = index;
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: borderColor, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  answers[index],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ---- 우: 해설 ----
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE1C7),
                          borderRadius: BorderRadius.circular(12),
                          border:
                          Border.all(color: Colors.orange, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            explanationIndex == null
                                ? (isTimeout
                                ? "시간 초과로 오답 처리되었습니다.\n좌측에서 항목을 눌러 해설을 확인하세요."
                                : "오답을 탭하면\n해설이 표시됩니다.")
                                : explanations[explanationIndex!],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15),
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
    );
  }
}
