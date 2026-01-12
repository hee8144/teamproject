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

    String resultTitle;
    Color themeColor;
    IconData resultIcon;

    if (isTimeout) {
      resultTitle = "시간 초과!";
      themeColor = const Color(0xFFD84315);
      resultIcon = Icons.timer_off_outlined;
    } else if (widget.isCorrect) {
      resultTitle = "정답입니다!";
      themeColor = const Color(0xFF2E7D32);
      resultIcon = Icons.check_circle_outline;
    } else {
      resultTitle = "오답입니다!";
      themeColor = const Color(0xFFC62828);
      resultIcon = Icons.cancel_outlined;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800,
                maxHeight: size.height * 0.85,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF5E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF5D4037),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF5D4037),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: const Center(
                        child: Text(
                          "퀴즈 결과 확인",
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
                                  Icon(resultIcon, size: 70, color: themeColor),
                                  const SizedBox(height: 10),
                                  Text(
                                    resultTitle,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: themeColor,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildMySelectionBox(isTimeout),
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

                            // [우측] 해설 및 정보 영역 (60%)
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 해설 내용을 스크롤 가능하게 배치
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: _buildExplanationContent(),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5D4037),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), // 클릭 영역 확대
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text(
                                        "확 인",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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


  Widget _buildMySelectionBox(bool isTimeout) {
    if (widget.isCorrect) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4C4A8)),
      ),
      child: Column(
        children: [
          if (isTimeout)
            const Text(
              "시간이 초과되어\n답을 선택하지 못했습니다.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFFD84315), fontWeight: FontWeight.w600),
            )
          else ...[
            const Text("내가 선택한 오답", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              widget.question.choices[widget.selectedIndex],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC62828),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExplanationContent() {
    String rawExplanation = "";
    if (widget.isCorrect) {
      rawExplanation = widget.question.explanations[widget.question.correctIndex];
    } else if (widget.selectedIndex != -1) {
      rawExplanation = widget.question.explanations[widget.selectedIndex];
    } else {
      rawExplanation = widget.question.explanations[widget.question.correctIndex];
    }

    // 2. 텍스트 파싱
    final parts = rawExplanation.split("\n\n");
    String titleSection = parts.isNotEmpty ? parts[0] : "";
    String bodySection = parts.length > 1 ? parts.sublist(1).join("\n\n") : "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // (1) 결과 메시지 박스
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isCorrect 
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isCorrect ? Colors.green : Colors.redAccent,
              width: 1.5,
            ),
          ),
          child: Text(
            titleSection,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.isCorrect ? Colors.green[800] : Colors.red[800],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // (2) 상세 설명 박스
        if (bodySection.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD4C4A8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF5D4037)),
                    SizedBox(width: 8),
                    Text(
                      "문화재 정보",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14, color: Color(0xFFEFEBE9)),
                Text(
                  bodySection,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}