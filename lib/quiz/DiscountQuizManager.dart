import 'dart:math';
import 'package:flutter/material.dart';
import 'quiz_repository.dart';
import 'quiz_dialog.dart';
import 'quiz_result_popup.dart';
import 'quiz_question.dart';

class DiscountQuizManager {
  static Future<bool> startDiscountQuiz(BuildContext context, String purpose) async {
    // 1. 50% 확률 체크
    final random = Random();
    bool shouldShowQuiz = random.nextBool(); 

    if (!shouldShowQuiz) {
      print("$purpose 퀴즈 미발생");
      return false; 
    }

    // 퀴즈 시작 알림
    if (context.mounted) {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // 💡 추가

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✨ $purpose 50% 할인 찬스! 퀴즈가 시작됩니다!", textAlign: TextAlign.center),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.deepPurple.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: screenHeight - 60,
            left: screenWidth * 0.2,
            right: screenWidth * 0.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
    }
    
    // 약간의 딜레이 후 퀴즈 진입
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // 2. 퀴즈 데이터 가져오기
      final QuizQuestion question = await QuizRepository.getRandomQuiz();

      if (!context.mounted) return false;

      int selectedIndex = -1;
      bool isCorrect = false;

      // 3. 퀴즈 다이얼로그 표시
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => QuizDialog(
          question: question,
          onQuizFinished: (index, correct) {
            selectedIndex = index;
            isCorrect = correct;
          },
        ),
      );

      if (!context.mounted) return false;

      // 4. 결과 팝업 표시
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => QuizResultPopup(
          question: question,
          selectedIndex: selectedIndex,
          isCorrect: isCorrect,
        ),
      );

      // 5. 정답 시 할인 확정 안내
      if (isCorrect && context.mounted) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        ScaffoldMessenger.of(context).removeCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 축하합니다! $purpose 50% 할인이 적용됩니다!", textAlign: TextAlign.center),
            backgroundColor: Colors.green.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: screenHeight - 60, 
              left: screenWidth * 0.2,
              right: screenWidth * 0.2,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
      }

      return isCorrect;

    } catch (e) {
      print("할인 퀴즈 오류: $e");
      return false;
    }
  }
}