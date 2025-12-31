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
import 'toll_quiz_manager.dart'; // 💡 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 💡 가로 모드로 고정
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
  bool _isLoading = false; // 로딩 상태

  // 🧪 퀴즈 -> 결과 -> 찬스카드 전체 흐름 실행
  Future<void> _startChanceSequence() async {
    setState(() {
      _isLoading = true;
      lastLog = "퀴즈 데이터 로딩 중...";
    });

    try {
      // 1. 실제 DB에서 랜덤 퀴즈 가져오기
      final QuizQuestion quizQuestion = await QuizRepository.getRandomQuiz();

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      int selectedIndex = -1;
      bool isCorrect = false;

      // 2. 퀴즈 다이얼로그 호출
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

      // 3. 퀴즈 결과 팝업 호출
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

      // 4. 찬스 카드 뽑기 (퀴즈 결과 반영)
      final result = await showDialog(
        context: context,
        useSafeArea: false, // 💡 전체 화면 사용
        builder: (_) => ChanceCardQuizAfter(
          quizEffect: isCorrect,
          storedCard: myStoredCard, 
        ),
      );

      // 5. 최종 결과 처리 (GameMain 역할 시뮬레이션)
      if (result != null) {
        _processResult(result.toString());
      } else {
        setState(() => lastLog = "카드를 뽑지 않고 닫았거나 에러 발생");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        lastLog = "에러 발생: $e";
      });
      print("퀴즈 로딩 에러: $e");
    }
  }

  void _processResult(String action) {
    String logMessage = "";

    // 1. 보관형 카드 획득/교체 (store:..., replace:...)
    if (action.startsWith("store:") || action.startsWith("replace:")) {
      // "store:c_shield" -> "shield" 추출 (GameMain 로직 동일)
      final rawKey = action.split(":")[1]; 
      final realKey = rawKey.replaceFirst("c_", ""); 
      
      setState(() {
        myStoredCard = realKey;
        logMessage = "카드 저장 완료: $realKey (원본: $rawKey)";
      });
    }
    // 2. 버리기 (discard)
    else if (action == "discard") {
      logMessage = "새 카드를 버리고 기존 카드($myStoredCard) 유지";
    }
    // 3. 즉시 이동 (move_start, go_island 등)
    else if (action == "move_start") {
      logMessage = "출발지로 이동합니다!";
    }
    else if (action == "go_island") {
      logMessage = "무인도로 이동합니다!";
    }
    // 4. 기타 즉시 효과
    else {
      logMessage = "즉시 효과 발동: $action";
    }

    setState(() {
      lastLog = logMessage;
    });
    _showToast(logMessage);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("찬스카드 전체 흐름 테스트 (실제 DB)")),
      backgroundColor: Colors.grey[200],
      body: Stack(
        children: [
          SingleChildScrollView( // 💡 스크롤 가능하게 변경
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(20),
                      width: 500, // 너비 고정하여 가로모드 최적화
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: Column(
                        children: [
                          const Text("--- 내 상태 ---", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text("보유 카드: $myStoredCard", style: const TextStyle(fontSize: 20, color: Colors.blue)),
                          const Divider(),
                          Text(lastLog, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("퀴즈부터 시작하기 (DB 연동)"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _isLoading ? null : _startChanceSequence,
                    ),
                    const SizedBox(height: 15),
                    const Text("--- 로직 강제 테스트 (팝업 확인용) ---", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    ElevatedButton(
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
                          useSafeArea: false, // 💡 전체 화면 사용
                          builder: (_) => ChanceCardQuizAfter(
                            quizEffect: true,
                            storedCard: myStoredCard,
                            debugCard: dummyEscapeCard,
                          ),
                        );
                        if (result != null) _processResult(result.toString());
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                      child: const Text("보관용 카드 테스트 (교체 팝업 강제)"),
                    ),
                    const SizedBox(height: 15),
                    const Text("--- DB 직접 수정 시뮬레이션 ---", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      // 2. 통행료 퀴즈 테스트 추가
                      ElevatedButton.icon(
                        icon: const Icon(Icons.money_off),
                        label: const Text("통행료 할인 퀴즈 테스트"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () async {
                          setState(() {
                            lastLog = "통행료 퀴즈 주사위 굴리는 중 (50% 확률)...";
                          });
                          
                          // 💡 새로 만든 매니저 호출
                          final bool isDiscounted = await TollQuizManager.startTollQuiz(context);
                          
                          setState(() {
                            if (isDiscounted) {
                              lastLog = "🎉 퀴즈 정답! 통행료 50% 할인 적용 대상입니다.";
                            } else {
                              lastLog = "❌ 할인 불가 (퀴즈 미발생 또는 오답)";
                            }
                          });
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 3. 팝업 강제 테스트 (기존 2번)
                      Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => _processResult('c_escape'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                          child: const Text("무인도 탈출권 획득"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => _processResult('c_shield'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                          child: const Text("방어권 획득"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              myStoredCard = "N";
                              lastLog = "상태 리셋 완료";
                            });
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                          child: const Text("보유카드 리셋"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}