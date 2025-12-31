import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'chance_card.dart';
import 'chance_card_quiz_after.dart';
import 'quiz_dialog.dart';
import 'quiz_question.dart';
import 'quiz_repository.dart';
import 'quiz_result_popup.dart';
import 'DiscountQuizManager.dart';
import '../Popup/Construction.dart';
import '../Popup/Takeover.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TestChanceCardLogic(),
    );
  }
}

class TestChanceCardLogic extends StatefulWidget {
  const TestChanceCardLogic({super.key});

  @override
  State<TestChanceCardLogic> createState() => _TestChanceCardLogicState();
}

class _TestChanceCardLogicState extends State<TestChanceCardLogic> {
  String myStoredCard = "shield"; 
  int myMoney = 5000000;
  String lastLog = "테스트 대기 중...";
  bool _isLoading = false; 

  Future<void> _startChanceSequence() async {
    setState(() {
      _isLoading = true;
      lastLog = "퀴즈 데이터 로딩 중...";
    });

    try {
      final QuizQuestion quizQuestion = await QuizRepository.getRandomQuiz();
      setState(() => _isLoading = false);

      if (!mounted) return;

      int selectedIndex = -1;
      bool isCorrect = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => QuizDialog(
          question: quizQuestion,
          onQuizFinished: (index, correct) {
            selectedIndex = index;
            isCorrect = correct;
          },
        ),
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => QuizResultPopup(
          question: quizQuestion,
          selectedIndex: selectedIndex,
          isCorrect: isCorrect,
        ),
      );

      if (!mounted) return;

      final result = await showDialog(
        context: context,
        useSafeArea: false, // 💡 찬스카드는 전체 화면 사용 (잘림 방지)
        builder: (_) => ChanceCardQuizAfter(
          quizEffect: isCorrect,
          storedCard: myStoredCard, 
        ),
      );

      if (result != null) {
        _processResult(result.toString());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        lastLog = "에러 발생: $e";
      });
    }
  }

  void _processResult(String action) {
    String logMessage = "";
    if (action.startsWith("store:") || action.startsWith("replace:")) {
      final realKey = action.split(":")[1].replaceFirst("c_", ""); 
      setState(() {
        myStoredCard = realKey;
        logMessage = "카드 저장 완료: $realKey";
      });
    } else if (action == "discard") {
      logMessage = "기존 카드($myStoredCard) 유지";
    } else if (action == "move_start") {
      logMessage = "출발지 이동!";
    } else if (action == "go_island") {
      logMessage = "무인도 이동!";
    } else {
      logMessage = "효과 발동: $action";
    }

    setState(() => lastLog = logMessage);
    _showToast(logMessage);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("할인 퀴즈 및 찬스카드 테스트")),
      backgroundColor: Colors.grey[200],
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: 500,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: Column(
                        children: [
                          const Text("--- 내 상태 ---", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("보유 카드: $myStoredCard", style: const TextStyle(fontSize: 20, color: Colors.blue)),
                          const Divider(),
                          Text(lastLog, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 1. 찬스카드 테스트
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("퀴즈 + 찬스카드 전체 흐름"),
                      onPressed: _isLoading ? null : _startChanceSequence,
                    ),
                    const SizedBox(height: 10),
                    
                    // 2. 통행료 퀴즈 테스트
                    ElevatedButton.icon(
                      icon: const Icon(Icons.money_off),
                      label: const Text("통행료 할인 퀴즈 테스트 (50%)"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      onPressed: () async {
                        final bool isDiscounted = await DiscountQuizManager.startDiscountQuiz(context, "통행료");
                        setState(() {
                          lastLog = isDiscounted ? "🎉 통행료 50% 할인 확정!" : "❌ 할인 실패";
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // 💡 [복구] 보관용 카드 테스트 버튼
                    ElevatedButton.icon(
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text("보관용 카드 테스트 (교체 팝업 강제)"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                      onPressed: () async {
                        final dummyEscapeCard = ChanceCard(
                          title: "무인도 탈출",
                          description: "무인도에서 즉시 탈출하거나,\n나중에 사용할 수 있습니다.",
                          type: "benefit",
                          action: "c_escape",
                          imageKey: "c_escape",
                        );
                        final result = await showDialog(
                          context: context,
                          useSafeArea: false, // 💡 전체 화면
                          builder: (_) => ChanceCardQuizAfter(
                            quizEffect: true,
                            storedCard: myStoredCard,
                            debugCard: dummyEscapeCard,
                          ),
                        );
                        if (result != null) _processResult(result.toString());
                      },
                    ),
                    const SizedBox(height: 30),
                    
                    ElevatedButton(
                      onPressed: () => setState(() => myStoredCard = "N"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text("보유카드 리셋 (N으로 변경)"),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
