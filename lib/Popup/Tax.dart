import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:teamproject/Popup/warning.dart';
import '../firebase_options.dart';
import '../quiz/chance_card_quiz_after.dart';
import '../quiz/quiz_dialog.dart';
import '../quiz/quiz_repository.dart';
import 'Bankruptcy.dart';
import 'ChanceCard.dart';
import 'Takeover.dart';
import 'TaxDialog.dart';
import 'Construction.dart';
import 'Island.dart';
import 'Travel.dart';
import 'Origin.dart';
import 'Detail.dart';
import 'BoardDetail.dart';
import 'CardUse.dart';
import 'check.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Firebase 초기화 설정
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TaxPage(),
    );
  }
}


Future<void> showWarningIfNeeded(BuildContext context) async {
  final checker = WarningChecker();
  final result = await checker.check();

  if (result == null) return; // 🔥 조건 불충족 → 아무 것도 안 함

  showDialog(
    context: context,
    builder: (_) => WarningDialog(
      players: result.players,
      type: result.type,
    ),
  );
}
class TaxPage extends StatelessWidget {
  const TaxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        title: const Text("문화재 마블"),
        backgroundColor: const Color(0xFF607D8B),
      ),
      body: Center(
        child: Container(
          width: 720,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F6F1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF8D6E63), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "행동을 선택하세요",
                style: TextStyle(fontSize: 20, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const TaxDialog(user: 1),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF607D8B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "세금 납부",
                        style: TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const IslandDialog(user: 1,),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D6E63),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "무인도",
                        style: TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  ElevatedButton(onPressed: (){
                    showDialog(context: context, builder: (context)=>CardUseDialog(user: 3));
                  }, child: Text("카드사용")),
                  ElevatedButton(onPressed: () async {
                    await showWarningIfNeeded(context);
                  }, child: Text("경고"))
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(onPressed: () async {
                    final result=
                    await showDialog(context: context,barrierDismissible: false, builder: (context)=>ConstructionDialog(buildingId: 1,user: 1,));
                  }, child: Text("건설")),
                  ElevatedButton(onPressed: () async {
                    await showDialog(context: context,barrierDismissible: false, builder: (context)=>TakeoverDialog(buildingId: 1,user: 1,));
                  }, child: Text("인수")),
                  ElevatedButton(onPressed: (){
                    showDialog(context: context, builder: (context)=>TravelDialog());
                  }, child: Text("여행")),
                  // ElevatedButton(
                  //   onPressed: () async {
                  //     final random = Random();
                  //     final bool showQuiz = random.nextBool(); // 50%
                  //
                  //     bool quizEffect = false;
                  //
                  //     if (showQuiz) {
                  //       // 1️⃣ 퀴즈 문제 하나 가져오기 (예시)
                  //       final question = await QuizRepository.getRandomQuiz();
                  //
                  //       await showDialog(
                  //         context: context,
                  //         barrierDismissible: false,
                  //         builder: (_) => QuizDialog(
                  //           question: question,
                  //           onQuizFinished: (selectedIndex, isCorrect) {
                  //             quizEffect = isCorrect;
                  //           },
                  //         ),
                  //       );
                  //     }
                  //
                  //     // 2️⃣ 카드 표시 (퀴즈를 했든 안 했든)
                  //     await showDialog(
                  //       context: context,
                  //       barrierDismissible: false,
                  //       builder: (_) => ChanceCardQuizAfter(
                  //         quizEffect: quizEffect,
                  //       ),
                  //     );
                  //   },
                  //   child: const Text("찬스카드"),
                  // ),
                  ElevatedButton(
                    onPressed: () async {
                      showDialog(context: context, builder: (context)=>ChancecardDialog());
                    },
                    child: const Text("찬스카드"),
                  ),
                  ElevatedButton(onPressed: (){
                    showDialog(context: context, builder: (context)=>OriginDialog(user: 1));
                  }, child: Text("출발지")),
                  ElevatedButton(onPressed: (){
                    showDialog(context: context, builder: (context)=>BankruptDialog(
                      lackMoney: 15000,
                      reason: "toll",
                      user: 1,
                    ));
                  }, child: Text("파산")),
                  ElevatedButton(onPressed: ()async{
                    final result = await showDialog(
                      context: context,
                      builder: (context) => DetailPopup(
                        boardNum: 2,
                        onNext: () {
                        },
                      ),
                    );
                    if(result != null){
                      showDialog(context: context, builder: (context)=>BoardDetail(boardNum: 1,data:result));
                    }
                  }, child: Text("디테일")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
