class QuizQuestion {
  final String title;          // 상단 제목 (ex. 경복궁 문화재 퀴즈!)
  final String question;       // 문제 문장
  final List<String> choices;  // 선택지 (4개 고정)
  final int correctIndex;      // 정답 인덱스 (0~3)
  final List<String> explanations; // 선택지별 해설

  const QuizQuestion({
    required this.title,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanations,
  });
}
