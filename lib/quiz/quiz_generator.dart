import 'dart:math';
import 'quiz_question.dart';

class QuizGenerator {
  static final Random _random = Random();

  static List<QuizQuestion> generateAllTypes({
    required Map<String, dynamic> target,
    required List<Map<String, dynamic>> pool,
  }) {
    return [
      _generateTimeQuiz(target, pool),
      _generateNameQuiz(target, pool),
      _generateDescriptionQuiz(target, pool),
    ];
  }

  // 공통 오답 풀 생성 로직
  static List<String> _getWrongPool(List<Map<String, dynamic>> pool, String field, String correctAnswer, List<String> defaultValues) {
    final List<String> wrongPool = pool
        .map((e) => e[field] as String?)
        .where((t) => t != null && t.trim().isNotEmpty && t != correctAnswer)
        .map((t) => t!)
        .toSet()
        .toList();

    if (wrongPool.length < 3) {
      wrongPool.addAll(defaultValues.where((d) => d != correctAnswer));
    }
    return wrongPool;
  }

  // 1. 연도 퀴즈
  static QuizQuestion _generateTimeQuiz(Map<String, dynamic> target, List<Map<String, dynamic>> pool) {
    final String name = target['name'] ?? '이 문화재';
    final String correctAnswer = target['times'] ?? '알 수 없음';
    
    final wrongPool = _getWrongPool(pool, 'times', correctAnswer, ['고려시대', '조선 전기', '일제강점기', '대한제국', '삼국시대']);
    final choices = _createChoices(correctAnswer, wrongPool);

    return QuizQuestion(
      title: "시대 퀴즈",
      question: "사진 속 문화재인\n'$name'의\n창건(제작) 시기는?",
      choices: choices,
      correctIndex: choices.indexOf(correctAnswer),
      explanations: _createExplanations(correctAnswer, target['description']),
      imageUrl: target['img'],
    );
  }

  // 2. 이름 퀴즈
  static QuizQuestion _generateNameQuiz(Map<String, dynamic> target, List<Map<String, dynamic>> pool) {
    final String correctAnswer = target['name'] ?? '이름 없음';
    
    final wrongPool = _getWrongPool(pool, 'name', correctAnswer, ['숭례문', '다보탑', '석가탑', '첨성대']);
    final choices = _createChoices(correctAnswer, wrongPool);

    return QuizQuestion(
      title: "이름 퀴즈",
      question: "다음 사진 속 문화재의\n이름은 무엇인가요?",
      choices: choices,
      correctIndex: choices.indexOf(correctAnswer),
      explanations: _createExplanations(correctAnswer, target['description']),
      imageUrl: target['img'],
    );
  }

  // 3. 설명 퀴즈
  static QuizQuestion _generateDescriptionQuiz(Map<String, dynamic> target, List<Map<String, dynamic>> pool) {
    final String name = target['name'] ?? '이 문화재';
    final String rawDesc = target['description'] ?? '';
    final String correctAnswer = name;

    // 설명 가공 (첫 1~2문장만 추출)
    final sentences = rawDesc.split('.');
    String shortDesc = sentences.first;
    if (shortDesc.length < 15 && sentences.length > 1) {
      shortDesc += ". ${sentences[1]}";
    }
    shortDesc += ".";

    // [최적화] 마스킹 로직: 정규식을 활용하여 한 번에 치환
    final List<String> parts = name.split(' ').where((p) => p.length >= 2).toList();
    final String pattern = ([name, ...parts].map((e) => RegExp.escape(e)).join('|'));
    String questionText = shortDesc.replaceAll(RegExp(pattern), "OOO");

    // 연속된 마스킹 정리
    while (questionText.contains("OOO OOO")) {
      questionText = questionText.replaceAll("OOO OOO", "OOO");
    }
    if (questionText.length > 80) questionText = "${questionText.substring(0, 80)}...";

    final wrongPool = _getWrongPool(pool, 'name', correctAnswer, ['숭례문', '다보탑', '석가탑', '첨성대']);
    final choices = _createChoices(correctAnswer, wrongPool);

    return QuizQuestion(
      title: "설명 퀴즈",
      question: "다음 설명에 해당하는 문화재는 무엇일까요?\n\n\"$questionText\"",
      choices: choices,
      correctIndex: choices.indexOf(correctAnswer),
      explanations: _createExplanations(correctAnswer, rawDesc),
      imageUrl: target['img'],
    );
  }

  static List<String> _createChoices(String correct, List<String> wrongPool) {
    final Set<String> choicesSet = {correct};
    final List<String> cleanWrongPool = List.from(wrongPool)..shuffle(_random);

    for (var wrong in cleanWrongPool) {
      if (choicesSet.length >= 4) break;
      
      bool isSimilar = choicesSet.any((existing) {
        String a = existing.replaceAll(" ", "").replaceAll("시대", "");
        String b = wrong.replaceAll(" ", "").replaceAll("시대", "");
        return a == b || a.contains(b) || b.contains(a);
      });

      if (!isSimilar) choicesSet.add(wrong);
    }
    
    // 부족분 채우기
    if (choicesSet.length < 4) {
       for (var d in ['경복궁', '불국사', '석굴암', '첨성대', '다보탑']) {
         if (choicesSet.length >= 4) break;
         choicesSet.add(d);
       }
    }

    return choicesSet.toList()..shuffle(_random);
  }

  static List<String> _createExplanations(String correct, String? desc) {
    return List.generate(4, (_) => "✅ 정답: $correct\n\n${desc ?? '설명이 없습니다.'}");
  }
}
