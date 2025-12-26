import 'dart:math';
import 'quiz_question.dart';

class QuizGenerator {
  static List<QuizQuestion> generateAllTypes({
    required Map<String, dynamic> target,
    required List<Map<String, dynamic>> pool,
  }) {
    final List<QuizQuestion> quizzes = [];

    quizzes.add(_generateTimeQuiz(target, pool)); // 연도 퀴즈
    quizzes.add(_generateNameQuiz(target, pool)); // 이름 퀴즈
    quizzes.add(_generateDescriptionQuiz(target, pool)); // 설명 퀴즈

    return quizzes;
  }

  // 1. 연도 퀴즈
  static QuizQuestion _generateTimeQuiz(
      Map<String, dynamic> target, List<Map<String, dynamic>> pool) {
    final String name = target['name'] ?? '이 문화재';
    final String correctAnswer = target['times'] ?? '알 수 없음';
    final String imageUrl = target['img'];

    final List<String> wrongPool = pool
        .map((e) => e['times'] as String?)
        .where((t) => t != null && t.trim().isNotEmpty && t != correctAnswer)
        .map((t) => t!)
        .toSet()
        .toList();

    if (wrongPool.length < 3) {
      wrongPool.addAll(['고려시대', '조선 전기', '일제강점기', '대한제국', '삼국시대']);
    }

    final choices = _createChoices(correctAnswer, wrongPool);

    return QuizQuestion(
      title: "시대 퀴즈",
      question: "사진 속 문화재인\n'$name'의\n창건(제작) 시기는?",
      choices: choices,
      correctIndex: choices.indexOf(correctAnswer),
      explanations: _createExplanations(correctAnswer, target['description']),
      imageUrl: imageUrl,
    );
  }

  // 2. 이름 퀴즈
  static QuizQuestion _generateNameQuiz(
      Map<String, dynamic> target, List<Map<String, dynamic>> pool) {
    final String correctAnswer = target['name'] ?? '이름 없음';
    final String imageUrl = target['img'];

    final List<String> wrongPool = pool
        .map((e) => e['name'] as String?)
        .where((n) => n != null && n.trim().isNotEmpty && n != correctAnswer)
        .map((n) => n!)
        .toList();

    // 오답 풀이 부족할 경우 기본값 추가 (안전장치)
    if (wrongPool.length < 3) {
      wrongPool.addAll(['숭례문', '다보탑', '석가탑', '첨성대']);
    }

    final choices = _createChoices(correctAnswer, wrongPool);

    return QuizQuestion(
      title: "이름 퀴즈",
      question: "다음 사진 속 문화재의\n이름은 무엇인가요?",
      choices: choices,
      correctIndex: choices.indexOf(correctAnswer),
      explanations: _createExplanations(correctAnswer, target['description']),
      imageUrl: imageUrl,
    );
  }

  // 3. 설명 퀴즈
  static QuizQuestion _generateDescriptionQuiz(
      Map<String, dynamic> target, List<Map<String, dynamic>> pool) {
    final String name = target['name'] ?? '이 문화재';
    final String rawDesc = target['description'] ?? '';
    final String correctAnswer = name;
    final String imageUrl = target['img'];

    // [설명 가공 로직]
    String shortDesc = rawDesc.split('.').first;
    if (shortDesc.length < 15 && rawDesc.contains('.')) {
      shortDesc += ". ${rawDesc.split('.')[1]}";
    }
    shortDesc += ".";

    // [마스킹 로직 강화]
    String questionText = shortDesc;
    
    // 1. 전체 이름 먼저 치환
    questionText = questionText.replaceAll(name, "OOO");

    // 2. 이름의 각 단어별 치환
    final List<String> nameParts = name.split(' ');
    for (var part in nameParts) {
      if (part.length >= 2) { // 두 글자 이상인 단어만
        questionText = questionText.replaceAll(part, "OOO");
      }
    }
    
    // 3. 연속된 마스킹 정리 (힌트 최소화)
    // "OOO OOO", "OOO OOO OOO" -> "OOO" 하나로 통일
    while (questionText.contains("OOO OOO")) {
      questionText = questionText.replaceAll("OOO OOO", "OOO");
    }
    
    // 4. 조사 연결 자연스럽게 (선택사항, "OOO은" / "OOO는" 등)
    // 여기서는 단순하게 유지

    // 3. 길이 제한
    if (questionText.length > 80) {
      questionText = "${questionText.substring(0, 80)}...";
    }

    final List<String> wrongPool = pool
        .map((e) => e['name'] as String?)
        .where((n) => n != null && n.trim().isNotEmpty && n != correctAnswer)
        .map((n) => n!)
        .toList();

    if (wrongPool.length < 3) {
      wrongPool.addAll(['숭례문', '다보탑', '석가탑', '첨성대']);
    }

    final choices = _createChoices(correctAnswer, wrongPool);

    return QuizQuestion(
      title: "설명 퀴즈",
      question: "다음 설명에 해당하는 문화재는 무엇일까요?\n\n\"$questionText\"",
      choices: choices,
      correctIndex: choices.indexOf(correctAnswer),
      explanations: _createExplanations(correctAnswer, rawDesc),
      imageUrl: imageUrl,
    );
  }

  // [유틸] 보기 섞기 (빈칸 방지 로직 포함)
  static List<String> _createChoices(String correct, List<String> wrongPool) {
    final random = Random();
    final Set<String> choicesSet = {};
    
    // 빈 문자열 제거
    wrongPool.removeWhere((element) => element.trim().isEmpty);

    // 오답 3개 뽑기
    int retryCount = 0;
    while (choicesSet.length < 3 && wrongPool.isNotEmpty) {
      final wrong = wrongPool[random.nextInt(wrongPool.length)];
      if (wrong != correct) {
        choicesSet.add(wrong);
      }
      
      // 무한루프 방지
      retryCount++;
      if (retryCount > 20) break;
    }
    
    // 그래도 부족하면 더미 추가
    if (choicesSet.length < 3) {
       final dummies = ['경복궁', '불국사', '석굴암'];
       for (var d in dummies) {
         if (d != correct && !choicesSet.contains(d)) {
           choicesSet.add(d);
           if (choicesSet.length == 3) break;
         }
       }
    }

    final List<String> choices = choicesSet.toList();
    choices.add(correct);
    choices.shuffle();
    
    return choices;
  }

  static List<String> _createExplanations(String correct, String? desc) {
    final safeDesc = desc ?? '설명이 없습니다.';
    return List.generate(4, (index) {
      return "✅ 정답: $correct\n\n$safeDesc";
    });
  }
}