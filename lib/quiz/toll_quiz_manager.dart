import 'dart:math';
import 'package:flutter/material.dart';
import 'quiz_repository.dart';
import 'quiz_dialog.dart';
import 'quiz_result_popup.dart';
import 'quiz_question.dart';

class TollQuizManager {
  /// 상대방 땅에 도착했을 때 호출하는 함수입니다.
  /// 50% 확률로 퀴즈를 발생시키고, 정답 여부를 반환합니다.
  static Future<bool> startTollQuiz(BuildContext context) async {
    // [1단계] 50% 확률로 퀴즈 발생 여부 결정
    final random = Random();
    bool shouldShowQuiz = random.nextBool();

    if (!shouldShowQuiz) {
      print("통행료 퀴즈: 당첨 실패 (퀴즈 없이 바로 통행료 지불)");
      return false;
    }

    print("통행료 퀴즈: 당첨! 퀴즈 로직 시작");
    
    try {
      // 1. 퀴즈 데이터 가져오기
      final QuizQuestion question = await QuizRepository.getRandomQuiz();

      if (!context.mounted) return false;

      int selectedIndex = -1;
      bool isCorrect = false;

      // 2. 퀴즈 다이얼로그 표시
      await showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (_) => QuizDialog(
          question: question,
          onQuizFinished: (index, correct) {
            selectedIndex = index;
            isCorrect = correct;
          },
        ),
      );

      if (!context.mounted) return false;

      // 3. 결과 팝업 표시
      await showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (_) => QuizResultPopup(
          question: question,
          selectedIndex: selectedIndex,
          isCorrect: isCorrect,
        ),
      );

      // 4. 정답 여부 반환 (정답일 때만 할인 적용)
      return isCorrect;

    } catch (e) {
      print("통행료 퀴즈 오류: $e");
      return false; // 오류 시 할인 없음
    }
  }
}
