import 'package:flutter/material.dart';

void main() {
  runApp(const QuizResultDummyApp());
}

class QuizResultDummyApp extends StatelessWidget {
  const QuizResultDummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QuizResultDummyPage(),
    );
  }
}

class QuizResultDummyPage extends StatelessWidget {
  const QuizResultDummyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E1F1B),
      body: Stack(
        children: [
          // ===== 게임 화면 더미 =====
          const Center(
            child: Text(
              "GAME SCREEN",
              style: TextStyle(color: Colors.white38, fontSize: 22),
            ),
          ),

          // ===== 어두운 오버레이 =====
          Container(color: Colors.black.withOpacity(0.6)),

          // ===== 퀴즈 결과 팝업 =====
          const QuizResultPopup(),
        ],
      ),
    );
  }
}

/* ================= 결과 팝업 ================= */

class QuizResultPopup extends StatelessWidget {
  const QuizResultPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE63946), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 닫기 버튼
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {},
              ),
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                // 결과 텍스트
                const Text(
                  "오답입니다!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE63946),
                  ),
                ),

                const SizedBox(height: 16),

                // 선택지 결과 영역
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1번: 내가 고른 오답
                      ResultItem(
                        text: "① 고려",
                        isCorrectAnswer: false,
                        isUserChoice: true,
                        explanation:
                        "경복궁은 고려 시대에 지어진 궁궐이 아닙니다.",
                      ),

                      // 2번: 정답
                      ResultItem(
                        text: "② 조선",
                        isCorrectAnswer: true,
                        isUserChoice: false,
                        explanation:
                        "경복궁은 조선 태조 이성계가 1395년에 건설한 궁궐입니다.",
                      ),

                      // 3번: 오답
                      ResultItem(
                        text: "③ 신라",
                        isCorrectAnswer: false,
                        isUserChoice: false,
                        explanation:
                        "신라 시대의 궁궐은 경복궁과 관련이 없습니다.",
                      ),

                      // 4번: 오답
                      ResultItem(
                        text: "④ 대한제국",
                        isCorrectAnswer: false,
                        isUserChoice: false,
                        explanation:
                        "경복궁은 대한제국 이전에 이미 존재했습니다.",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= 선택지 결과 아이템 ================= */

class ResultItem extends StatefulWidget {
  final String text;
  final bool isCorrectAnswer;
  final bool isUserChoice;
  final String explanation;

  const ResultItem({
    super.key,
    required this.text,
    required this.isCorrectAnswer,
    required this.isUserChoice,
    required this.explanation,
  });

  @override
  State<ResultItem> createState() => _ResultItemState();
}

class _ResultItemState extends State<ResultItem> {
  bool showExplanation = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;

    if (widget.isCorrectAnswer) {
      bgColor = const Color(0xFFE0F2F1);
    } else if (widget.isUserChoice) {
      bgColor = const Color(0xFFFFCDD2);
    }

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (!widget.isCorrectAnswer) {
              setState(() {
                showExplanation = !showExplanation;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isCorrectAnswer
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: widget.isCorrectAnswer
                      ? Colors.green
                      : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontWeight: widget.isCorrectAnswer
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.isUserChoice)
                  const Text(
                    "내 선택",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ===== 해설 박스 (오답 + 탭 시) =====
        if (!widget.isCorrectAnswer && showExplanation)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orangeAccent),
            ),
            child: Text(
              widget.explanation,
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }
}
