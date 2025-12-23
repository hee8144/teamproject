import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp을 먼저 띄우고, home에서 실제 페이지 위젯을 호출합니다.
    return const MaterialApp(
      home: TaxPage(),
    );
  }
}


class TaxPage extends StatefulWidget {
  const TaxPage({super.key});

  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  Future<void> _readdUser() async {
    final snapshot = await fs.collection("games").doc("users").get();
    print(snapshot);
  }
  @override
  Widget build(BuildContext context) {
    // 이제 여기서의 context는 MaterialApp 내부의 context이므로 에러가 나지 않습니다.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async{
                _readdUser();
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        width: 400,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                "국세청",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold,fontSize: 20),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "보유 건물의 세금 10%\n를 징수합니다!",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("지불하기"),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: const Text("클릭"),
            )
          ],
        ),
      ),
    );
  }
}