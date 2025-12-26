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

    // 결과에 따른 테마 색상 및 텍스트 설정
    String resultTitle;
    Color themeColor;
    IconData resultIcon;

    if (isTimeout) {
      resultTitle = "시간 초과!";
      themeColor = const Color(0xFFD84315); // 진한 주황
      resultIcon = Icons.timer_off_outlined;
    } else if (widget.isCorrect) {
      resultTitle = "정답입니다!";
      themeColor = const Color(0xFF2E7D32); // 진한 초록
      resultIcon = Icons.check_circle_outline;
    } else {
      resultTitle = "오답입니다!";
      themeColor = const Color(0xFFC62828); // 진한 빨강
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
                                  Icon(resultIcon, size: 80, color: themeColor),
                                  const SizedBox(height: 16),
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
                                  const Text(
                                    "💡 상세 해설",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4E342E),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // 해설 내용을 스크롤 가능하게 배치
                                  Expanded(
                                    child: SingleChildScrollView(
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

  // 좌측 하단: 오답일 때만 내가 선택한 답을 보여줌
  Widget _buildMySelectionBox(bool isTimeout) {
    // 정답인 경우에는 박스를 보여주지 않음
    if (widget.isCorrect) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
                fontSize: 17,
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

  // 우측: 해설 내용 파싱 및 카드 UI 구성
  Widget _buildExplanationContent() {
    // 1. 해설 텍스트 가져오기
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
              fontSize: 15,
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFEFEBE9)),
                Text(
                  bodySection,
                  style: const TextStyle(
                    fontSize: 15,
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