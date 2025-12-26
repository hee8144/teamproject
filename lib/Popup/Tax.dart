import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';
import 'Takeover.dart';
import 'TaxDialog.dart';
import 'Construction.dart';
import 'Island.dart';

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
                          builder: (_) => const TaxDialog(user: 2),
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
                ],
              ),
              ElevatedButton(onPressed: () async {
                final result=
                await showDialog(context: context,barrierDismissible: false, builder: (context)=>ConstructionDialog(buildingId: 1,user: 1,));
              }, child: Text("건설")),
              ElevatedButton(onPressed: () async {
                await showDialog(context: context,barrierDismissible: false, builder: (context)=>TakeoverDialog(buildingId: 1,user: 1,));
              }, child: Text("인수")),
            ],
          ),
        ),
      ),
    );
  }
}
