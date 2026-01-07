import 'dart:math';
import 'package:flutter/foundation.dart'; // ✅ 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_question.dart';
import 'quiz_generator.dart';

class QuizRepository {
  static List<Map<String, dynamic>>? _cachedData;
  static Future<void>? _loadingFuture; // 💡 중복 로딩 방지를 위한 퓨처 저장소

  static Future<QuizQuestion> getRandomQuiz() async {
    // 💡 이미 로딩 중이라면 그 결과를 기다림
    if (_loadingFuture != null) await _loadingFuture;
    
    if (_cachedData == null || _cachedData!.isEmpty) {
      _loadingFuture = _loadAllData();
      await _loadingFuture;
      _loadingFuture = null; // 완료 후 초기화
    }

    if (_cachedData == null || _cachedData!.isEmpty) {
      throw Exception("퀴즈 데이터를 불러오지 못했습니다. (경로: games/quiz)");
    }

    final random = Random();
    final targetData = _cachedData![random.nextInt(_cachedData!.length)];

    final List<QuizQuestion> generatedQuizzes = QuizGenerator.generateAllTypes(
      target: targetData,
      pool: _cachedData!,
    );

    return generatedQuizzes[random.nextInt(generatedQuizzes.length)];
  }

  /// Firebase에서 데이터 로드
  static Future<void> _loadAllData() async {
    try {
      debugPrint("🔥 [QuizRepository] 데이터 로딩 시작 (games/quiz)...");
      final doc = await FirebaseFirestore.instance.collection('games').doc('quiz').get();

      if (!doc.exists) {
        debugPrint("❌ [QuizRepository] games/quiz 문서를 찾을 수 없습니다.");
        _cachedData = [];
        return;
      }

      final data = doc.data();
      if (data == null || data.isEmpty) {
        _cachedData = [];
        return;
      }

      final List<Map<String, dynamic>> loadedList = [];
      data.forEach((key, value) {
        if (key.startsWith('q') && value is Map) {
          final map = Map<String, dynamic>.from(value);

          // 필수 필드 검증
          bool isValid = 
              (map['name']?.toString().trim().isNotEmpty ?? false) &&
              (map['img']?.toString().trim().isNotEmpty ?? false) &&
              (map['times']?.toString().trim().isNotEmpty ?? false) &&
              (map['description']?.toString().trim().isNotEmpty ?? false);

          if (isValid) loadedList.add(map);
        }
      });

      _cachedData = loadedList;
      debugPrint("✅ [QuizRepository] 퀴즈 데이터 로드 완료: ${_cachedData!.length}개");
    } catch (e) {
      debugPrint("❌ [QuizRepository] 데이터 로드 중 에러: $e");
      _cachedData = [];
    }
  }

  static Future<QuizQuestion> getQuizForRegion(String regionName) async {
    if (_loadingFuture != null) await _loadingFuture;
    if (_cachedData == null || _cachedData!.isEmpty) {
      _loadingFuture = _loadAllData();
      await _loadingFuture;
      _loadingFuture = null;
    }
    
    // 안전한 데이터 추출
    if (_cachedData == null || _cachedData!.isEmpty) {
       throw Exception("데이터 로드 실패");
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