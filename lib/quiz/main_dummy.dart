import 'package:flutter/material.dart';
import 'quiz_dialog.dart';
import 'quiz_result_popup.dart';
import 'region_detail_popup.dart';
import 'chance_card_quiz_after.dart';
import 'quiz_question.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';


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

  void _openQuiz(QuizSource source) {
    _currentSource = source;

    // 더미 문제 1개 (나중에 DB에서 로드하면 여기만 교체)
    final question = QuizQuestion(
      title: "경복궁 문화재 퀴즈!",
      question: "경복궁은 어느 왕조 시대에 건설된 궁궐일까요?",
      choices: ["고려", "조선", "신라", "대한제국"],
      correctIndex: 1,
      explanations: [
        "고려는 아닙니다.",
        "조선 시대에 건설된 궁궐입니다.",
        "신라 시대는 아닙니다.",
        "대한제국 이전에 건설되었습니다.",
      ],
    );

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
  }

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
}
