import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_dialog.dart';
import 'quiz_result_popup.dart';
import 'region_detail_popup.dart';
import 'chance_card_quiz_after.dart';
import 'quiz_question.dart';
import 'quiz_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const QuizDummyApp());
}

enum QuizSource { chance, region }

class QuizDummyApp extends StatelessWidget {
  const QuizDummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DummyBoardScreen(),
    );
  }
}

class DummyBoardScreen extends StatefulWidget {
  const DummyBoardScreen({super.key});

  @override
  State<DummyBoardScreen> createState() => _DummyBoardScreenState();
}

class _DummyBoardScreenState extends State<DummyBoardScreen> {
  QuizSource? _currentSource;
  String? _lastChanceAction;

  // 퀴즈 1사이클 동안 유지돼야 하는 값들
  QuizQuestion? _currentQuestion;
  bool? _lastQuizCorrect;

  // ---------------------------------------------------------------------------
  // 퀴즈 열기 (DB 연동)
  // ---------------------------------------------------------------------------
  void _openQuiz(QuizSource source) async {
    _currentSource = source;

    // 로딩 인디케이터 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5D4037)),
      ),
    );

    try {
      // DB에서 랜덤 퀴즈 가져오기
      final question = await QuizRepository.getRandomQuiz();

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      _currentQuestion = question;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => QuizDialog(
          question: question,
          onQuizFinished: (selectedIndex, isCorrect) {
            _onQuizFinished(selectedIndex, isCorrect);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("퀴즈를 불러오지 못했습니다: $e")),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 퀴즈 종료 후 결과 팝업
  // ---------------------------------------------------------------------------
  void _onQuizFinished(int selectedIndex, bool isCorrect) {
    _lastQuizCorrect = isCorrect;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuizResultPopup(
        question: _currentQuestion!,
        selectedIndex: selectedIndex,
        isCorrect: isCorrect,
      ),
    ).then((_) {
      if (_currentSource == QuizSource.chance) {
        _openChanceAfter();
      } else if (_currentSource == QuizSource.region) {
        _openRegionDetail();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 찬스 카드 후속 팝업
  // ---------------------------------------------------------------------------
  void _openChanceAfter() async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChanceCardQuizAfter(
        quizEffect: _lastQuizCorrect == true,
      ),
    );

    if (action != null) {
      handleChanceCardAction(action);
    }
  }

  void handleChanceCardAction(String description) {
    setState(() {
      _lastChanceAction = description;
    });
  }

  // ---------------------------------------------------------------------------
  // 지역 상세 팝업
  // ---------------------------------------------------------------------------
  void _openRegionDetail() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegionDetailPopup(
        quizEffect: _lastQuizCorrect == true, // 정답일 때만 혜택
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E1F1B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _openQuiz(QuizSource.chance),
              child: const Text("찬스카드 퀴즈 발생"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openQuiz(QuizSource.region),
              child: const Text("문화재 지역 퀴즈 발생"),
            ),
            const SizedBox(height: 16),
            // --- 디버깅용 버튼 추가 ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              onPressed: _testLoadQ1,
              child: const Text("DB 연결 테스트 (q1)"),
            ),
            // -----------------------
            if (_lastChanceAction != null) ...[
              const SizedBox(height: 24),
              Text(
                '마지막 찬스카드 효과: $_lastChanceAction',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 디버깅용 메서드: games/quiz 문서 로드 후 q1 확인
  Future<void> _testLoadQ1() async {
    try {
      showDialog(
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      print("🔥 [Test] Fetching games/quiz...");
      final doc = await FirebaseFirestore.instance.collection('games').doc('quiz').get();
      
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      if (doc.exists) {
        final data = doc.data();
        final q1Data = data?['q1'];

        if (q1Data != null) {
          print("✅ [Test] q1 Success: $q1Data");
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("성공: q1 데이터"),
              content: SingleChildScrollView(
                child: Text(q1Data.toString()),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기")),
              ],
            ),
          );
        } else {
          print("❌ [Test] q1 field not found in quiz document");
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("실패"),
              content: const Text("quiz 문서 안에 'q1' 필드가 없습니다."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기")),
              ],
            ),
          );
        }
      } else {
        print("❌ [Test] quiz document not found in games collection");
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("실패"),
            content: const Text("문서(games/quiz)가 존재하지 않습니다."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기")),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기
      print("❌ [Test] Error: $e");
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("에러 발생"),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기")),
          ],
        ),
      );
    }
  }
}