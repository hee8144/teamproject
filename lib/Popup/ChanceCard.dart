import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../quiz/chance_card_quiz_after.dart';
import '../quiz/quiz_dialog.dart';
import '../quiz/quiz_question.dart';
import '../quiz/quiz_repository.dart';
import '../quiz/quiz_result_popup.dart';

class ChancecardDialog extends StatefulWidget {
  const ChancecardDialog({super.key});

  @override
  State<ChancecardDialog> createState() => _ChancecardDialogState();
}

class _ChancecardDialogState extends State<ChancecardDialog> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // 다이얼로그가 뜬 직후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runChanceFlow();
    });
  }

  Future<void> _runChanceFlow() async {
    final random = Random();
    final bool showQuiz = true; // ✅ 테스트 끝나면 random.nextBool()

    bool isCorrect = false;
    int? selectedIndex;
    QuizQuestion? question;

    if (showQuiz) {
      question = await QuizRepository.getRandomQuiz();

      // 1️⃣ 퀴즈
      await showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false, // 💡 전체 화면
        builder: (_) => QuizDialog(
          question: question!,
          onQuizFinished: (index, correct) {
            selectedIndex = index;
            isCorrect = correct;
          },
        ),
      );

      // 2️⃣ 결과
      await showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false, // 💡 전체 화면
        builder: (_) => QuizResultPopup(
          isCorrect: isCorrect,
          question: question!,
          selectedIndex: selectedIndex ?? -1,
        ),
      );
    }

    // 3️⃣ 찬스카드
    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false, // 💡 전체 화면
      builder: (_) => ChanceCardQuizAfter(
        quizEffect: isCorrect, storedCard: '', userIndex: 1,
      ),
    );

    Navigator.pop(context); // ChancecardDialog 닫기
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 400,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: CircularProgressIndicator(), // 로딩 연출
        ),
      ),
    );
  }
}