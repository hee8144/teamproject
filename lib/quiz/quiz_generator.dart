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

  static List<String> _createChoices(String correct, List<String> wrongPool) {
    final random = Random();
    final Set<String> choicesSet = {correct}; // 정답을 먼저 넣음
    
    // 오답 풀에서 빈 값 및 정답과 겹치는 값 제거
    final List<String> cleanWrongPool = wrongPool
        .where((e) => e.trim().isNotEmpty && e != correct)
        .toList();

    // 4개가 될 때까지 오답 추가
    while (choicesSet.length < 4 && cleanWrongPool.isNotEmpty) {
      final wrong = cleanWrongPool[random.nextInt(cleanWrongPool.length)];
      choicesSet.add(wrong);
      cleanWrongPool.remove(wrong); // 중복 방지를 위해 사용한 값은 제거
    }
    
    // 그래도 부족하면(데이터가 정말 없을 때) 더미 데이터 추가
    if (choicesSet.length < 4) {
       final dummies = ['경복궁', '불국사', '석굴암', '첨성대', '다보탑'];
       for (var d in dummies) {
         if (choicesSet.length >= 4) break;
         choicesSet.add(d);
       }
    }

    final List<String> choices = choicesSet.toList();
    choices.shuffle(); // 골고루 섞음
    
    return choices;
  }

  static List<String> _createExplanations(String correct, String? desc) {
    final safeDesc = desc ?? '설명이 없습니다.';
    return List.generate(4, (index) {
      return "✅ 정답: $correct\n\n$safeDesc";
    });
  }
}