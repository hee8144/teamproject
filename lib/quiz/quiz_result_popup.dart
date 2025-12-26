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
  @override
  Widget build(BuildContext context) {
    final bool isTimeout = widget.selectedIndex == -1;
    final size = MediaQuery.of(context).size;

    // 정답/오답 텍스트 및 색상 결정
    String resultTitle;
    Color titleColor;
    IconData resultIcon;

    if (isTimeout) {
      resultTitle = "시간 초과!";
      titleColor = const Color(0xFFD84315); // 진한 주황
      resultIcon = Icons.timer_off_outlined;
    } else if (widget.isCorrect) {
      resultTitle = "정답입니다!";
      titleColor = const Color(0xFF2E7D32); // 진한 초록
      resultIcon = Icons.check_circle_outline;
    } else {
      resultTitle = "오답입니다!";
      titleColor = const Color(0xFFC62828); // 진한 빨강
      resultIcon = Icons.cancel_outlined;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        children: [
          // 배경 오버레이
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800,
                maxHeight: size.height * 0.85,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF5E6), // 한지 배경
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF5D4037), // 나무 테두리
                    width: 6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 상단 타이틀 바
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF5D4037),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: const Center(
                        child: Text(
                          "퀴즈 결과",
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // [좌측] 결과 요약 (40%)
                            Expanded(
                              flex: 4,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(resultIcon, size: 80, color: titleColor),
                                  const SizedBox(height: 16),
                                  Text(
                                    resultTitle,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildAnswerSummary(isTimeout),
                                ],
                              ),
                            ),
                            
                            // 구분선
                            Container(
                              width: 2,
                              height: double.infinity,
                              color: const Color(0xFFD4C4A8),
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                            ),

                            // [우측] 해설 영역 (60%)
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    "💡 문화재 해설",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4E342E),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF8D6E63),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: SingleChildScrollView( // 해설이 길 경우 대비
                                        child: Text(
                                          _getExplanation(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            height: 1.6,
                                            color: Color(0xFF3E2723),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5D4037),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "확인",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSummary(bool isTimeout) {
    return Column(
      children: [
        if (!widget.isCorrect && !isTimeout) ...[
          const Text("내가 선택한 답", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            widget.question.choices[widget.selectedIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text("정답", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          widget.question.choices[widget.question.correctIndex],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  String _getExplanation() {
    // 선택한 답에 대한 해설 또는 정답 해설
    // 사용자가 답을 선택했으면 그 선택지에 해당하는 해설을 보여주는 것이 일반적이지만,
    // 정답을 맞추기 위한 학습 목적이라면 '정답 해설'을 보여주는 것이 더 좋을 수 있습니다.
    // 여기서는 정답에 대한 해설을 기본으로 보여주되, 오답 시 오답 이유도 포함하면 좋습니다.
    
    // 현재 데이터 구조상 explanations 리스트가 선택지 인덱스와 1:1 대응된다고 가정
    if (widget.isCorrect) {
      return widget.question.explanations[widget.question.correctIndex];
    } else if (widget.selectedIndex != -1) {
      // 오답인 경우: 오답 해설 + 정답 해설 같이 보여주기
      String wrongExpl = widget.question.explanations[widget.selectedIndex];
      String correctExpl = widget.question.explanations[widget.question.correctIndex];
      return "❌ 오답 이유:\n$wrongExpl\n\n✅ 정답 해설:\n$correctExpl";
    } else {
      // 시간 초과
      return "시간이 초과되었습니다.\n\n✅ 정답 해설:\n${widget.question.explanations[widget.question.correctIndex]}";
    }
  }
}