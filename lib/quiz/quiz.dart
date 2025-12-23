import 'package:flutter/material.dart';

void main() {
  runApp(const QuizDummyApp());
}

class QuizDummyApp extends StatelessWidget {
  const QuizDummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QuizDummyPage(),
    );
  }
}

class QuizDummyPage extends StatelessWidget {
  const QuizDummyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height > size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF2E1F1B),
      body: Stack(
        children: [
          // 게임 화면 더미
          const Center(
            child: Text(
              "GAME SCREEN",
              style: TextStyle(color: Colors.white38, fontSize: 22),
            ),
          ),

          // 어두운 오버레이
          Container(color: Colors.black.withOpacity(0.6)),

          // 퀴즈 카드
          Center(
            child: Container(
              width: size.width * 0.9,
              height: size.height * 0.8,
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
                  // 제목
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE1C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "경복궁 문화재 퀴즈!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 본문
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
        ],
      ),
    );
  }

  // ===== 세로 레이아웃 =====
  Widget _portraitLayout(BuildContext context) {
    return Column(
      children: [
        _imageBox(height: 140),
        const SizedBox(height: 12),
        _questionAndChoices(context),
      ],
    );
  }

  // ===== 가로 레이아웃 =====
  Widget _landscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _imageBox()),
        const SizedBox(width: 12),
        Expanded(child: _questionAndChoices(context)),
      ],
    );
  }

  // 이미지 영역
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

  // 문제 + 선택지
  Widget _questionAndChoices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 문제
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "경복궁은 어느 왕조 시대에 건설된 궁궐일까요?",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 선택지
        _choice(context, "① 고려"),
        _choice(context, "② 조선"),
        _choice(context, "③ 신라"),
        _choice(context, "④ 대한제국"),
      ],
    );
  }

  // ===== 선택지 버튼 =====
  Widget _choice(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showSubmitDialog(context, text);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF4A261),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
  }

  // ===== 제출 확인 다이얼로그 =====
  void _showSubmitDialog(BuildContext context, String answer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("제출 확인"),
          content: Text("선택한 답:\n\n$answer\n\n제출하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 결과 처리 예정 (지금은 더미)
              },
              child: const Text(
                "제출",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
