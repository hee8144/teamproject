import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_question.dart';
import 'quiz_generator.dart';

class QuizRepository {
  static List<Map<String, dynamic>>? _cachedData;

  static Future<QuizQuestion> getRandomQuiz() async {
    if (_cachedData == null || _cachedData!.isEmpty) {
      await _loadAllData();
    }

    if (_cachedData == null || _cachedData!.isEmpty) {
      throw Exception("퀴즈 데이터를 불러오지 못했습니다. (경로: games/quiz)");
    }

    final random = Random();
    final targetIndex = random.nextInt(_cachedData!.length);
    final targetData = _cachedData![targetIndex];

    final List<QuizQuestion> generatedQuizzes = QuizGenerator.generateAllTypes(
      target: targetData,
      pool: _cachedData!,
    );

    return generatedQuizzes[random.nextInt(generatedQuizzes.length)];
  }

  /// Firebase에서 데이터 로드 (games 컬렉션 -> quiz 문서 -> q1...q24 필드)
  static Future<void> _loadAllData() async {
    try {
      print("🔥 [QuizRepository] 데이터 로딩 시작 (games/quiz)...");
      final doc = await FirebaseFirestore.instance.collection('games').doc('quiz').get();

      if (!doc.exists) {
        print("❌ [QuizRepository] games/quiz 문서를 찾을 수 없습니다.");
        _cachedData = [];
        return;
      }

      final data = doc.data();
      if (data == null || data.isEmpty) {
        print("⚠️ [QuizRepository] quiz 문서가 비어있습니다.");
        _cachedData = [];
        return;
      }

      // q1, q2... 등 q로 시작하는 모든 맵 필드를 리스트로 추출
      final List<Map<String, dynamic>> loadedList = [];
      data.forEach((key, value) {
        if (key.startsWith('q') && value is Map) {
          final map = Map<String, dynamic>.from(value);

          // 💡 필수 필드 검증 (하나라도 비어있으면 퀴즈 목록에서 제외)
          bool isValid = 
              map['name']?.toString().trim().isNotEmpty == true &&
              map['img']?.toString().trim().isNotEmpty == true &&
              map['times']?.toString().trim().isNotEmpty == true &&
              map['description']?.toString().trim().isNotEmpty == true;

          if (isValid) {
            loadedList.add(map);
          } else {
            print("⚠️ [QuizRepository] 부실 데이터 제외됨: $key");
          }
        }
      });

      _cachedData = loadedList;
      print("✅ [QuizRepository] 퀴즈 데이터 로드 완료: ${_cachedData!.length}개");
    } catch (e) {
      print("❌ [QuizRepository] 데이터 로드 중 에러: $e");
      _cachedData = [];
    }
  }

  static Future<QuizQuestion> getQuizForRegion(String regionName) async {
    if (_cachedData == null || _cachedData!.isEmpty) {
      await _loadAllData();
    }
    
    final targetData = _cachedData!.firstWhere(
      (data) => data['name'] == regionName,
      orElse: () => _cachedData![Random().nextInt(_cachedData!.length)],
    );
    
    final generatedQuizzes = QuizGenerator.generateAllTypes(
      target: targetData,
      pool: _cachedData!,
    );
    
    return generatedQuizzes[Random().nextInt(generatedQuizzes.length)];
  }
}