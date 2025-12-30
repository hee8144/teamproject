import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_dialog.dart';
import 'quiz_result_popup.dart';
import 'region_detail_popup.dart';
import 'chance_card_quiz_after_v2.dart'; // V2 import
import 'quiz_question.dart';
import 'quiz_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화는 유지 (퀴즈 데이터 등을 위해 필요할 수 있음)
  // 만약 이것도 안되면 try-catch로 감싸거나 주석 처리
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase init failed (Test Mode): $e");
  }
  
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
  String? _lastLog; // 마지막 로그 메시지

  // 퀴즈 1사이클 동안 유지돼야 하는 값들
  QuizQuestion? _currentQuestion;
  bool? _lastQuizCorrect;

  // ---------------------------------------------------------------------------
  // [테스트용] 상태 조작 함수
  // ---------------------------------------------------------------------------
  void _setTestCardStatus(String cardStatus) {
    // V2 파일 내의 static 변수를 직접 수정하여 Mocking
    ChanceCardQuizAfterV2.testUserMock['card'] = cardStatus;
    
    String cardName = cardStatus == 'N' ? '없음' : (cardStatus == 'escape' ? '무인도 탈출' : 'VIP 명찰');
    setState(() {
      _lastLog = "👉 상태 변경됨: 보유카드 = $cardName";
    });
  }

  // ---------------------------------------------------------------------------
  // 퀴즈 열기
  // ---------------------------------------------------------------------------
  void _openQuiz(QuizSource source) async {
    _currentSource = source;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5D4037)),
      ),
    );

    try {
      final question = await QuizRepository.getRandomQuiz();

      if (!mounted) return;
      Navigator.pop(context); 

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
      Navigator.pop(context); 

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("퀴즈를 불러오지 못했습니다: $e")),
      );
    }
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

  // ---------------------------------------------------------------------------
  // 찬스 카드 후속 팝업 (V2 - 테스트 모드)
  // ---------------------------------------------------------------------------
  void _openChanceAfter() async {
    // V2 위젯 호출
    // 테스트 모드이므로 내부에서 testUserMock을 읽고 씀
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChanceCardQuizAfterV2(
        quizEffect: _lastQuizCorrect == true,
      ),
    );
    
    // 팝업이 닫힌 후 현재 상태 확인
    _checkCurrentStatus();
  }
  
  void _checkCurrentStatus() {
    final currentCard = ChanceCardQuizAfterV2.testUserMock['card'];
    String cardName = currentCard == 'N' ? '없음' : (currentCard == 'escape' ? '무인도 탈출' : 'VIP 명찰');
    
    setState(() {
      _lastLog = "✅ 로직 종료 후 상태: 보유카드 = $cardName";
    });
  }

  void _openRegionDetail() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegionDetailPopup(
        quizEffect: _lastQuizCorrect == true, 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E1F1B),
      appBar: AppBar(
        title: const Text("퀴즈 & 찬스카드 테스트 (V2)"),
        backgroundColor: const Color(0xFF5D4037),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // [테스트 컨트롤 패널]
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    const Text(
                      "🛠️ 가상 DB(TestMode) 상태 조작",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    const Text("내 보유 카드 설정:", style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _testButton("없음 (N)", () => _setTestCardStatus('N')),
                        _testButton("탈출권", () => _setTestCardStatus('escape')),
                        _testButton("VIP", () => _setTestCardStatus('sheild')),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                onPressed: () => _openQuiz(QuizSource.chance),
                child: const Text("🎲 찬스카드 퀴즈 시작", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 30),
              
              // [로그 출력]
              if (_lastLog != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lastLog!,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _testButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
