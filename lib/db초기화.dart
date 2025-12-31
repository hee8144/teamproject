import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Board Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BoardAdminPage(),
    );
  }
}

class BoardAdminPage extends StatefulWidget {
  const BoardAdminPage({super.key});

  @override
  State<BoardAdminPage> createState() => _BoardAdminPageState();
}

class _BoardAdminPageState extends State<BoardAdminPage> {
  // 입력 컨트롤러 (개별 수정용)
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _indexController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tollController = TextEditingController();
  final TextEditingController _groupController = TextEditingController(); // 💡 그룹 수정용 컨트롤러 추가

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // [기능 1] 28칸 전체 초기화 (그룹 추가됨)
  Future<void> _initializeBoardLayout() async {
    Map<String, dynamic> fullBoardData = {};
    int landCount = 0;

    // 💡 7칸 시스템에 맞춰 28번까지 반복 (0~27)
    for (int i = 0; i < 28; i++) {
      String key = "b$i";
      String type = "land";
      String? name;

      // 1. 특수 블록 지정
      if (i == 0) { type = "start"; name = "출발지"; }
      else if (i == 7) { type = "island"; name = "무인도"; }
      else if (i == 14) { type = "festival"; name = "지역축제"; }
      else if (i == 21) { type = "travel"; name = "국내여행"; }
      else if (i == 26) { type = "tax"; name = "국세청"; }
      else if ([3, 10, 17, 24].contains(i)) { type = "chance"; name = "찬스"; }

      Map<String, dynamic> blockData = {
        "index": i,
        "type": type,
        "name": name,
      };

      // 2. 땅(land)일 때만 그룹 및 가격 계산 로직 수행
      if (type == "land") {
        int calculatedToll = 100000 + (landCount * 10000);

        // 💡 [그룹 할당 로직]
        // 1라인: 2개 / 3개
        // 2라인: 2개 / 3개
        // 3라인: 2개 / 3개
        // 4라인: 2개 / 2개 (26번 국세청 제외)
        int group = 0;

        if (i == 1 || i == 2) group = 1;
        else if (i >= 4 && i <= 6) group = 2;
        else if (i == 8 || i == 9) group = 3;
        else if (i >= 11 && i <= 13) group = 4;
        else if (i == 15 || i == 16) group = 5;
        else if (i >= 18 && i <= 20) group = 6;
        else if (i == 22 || i == 23) group = 7;
        else if (i == 25 || i == 27) group = 8; // 26번은 국세청이라 제외

        blockData.addAll({
          "name": "일반 땅 ${landCount + 1}",
          "level": 0,
          "owner": "N",
          "tollPrice": calculatedToll,
          "isFestival": false,
          "multiply": 1,
          "group": group, // 💡 그룹 정보 저장 (1~8)
        });
        landCount++;
      }
      fullBoardData[key] = blockData;
    }

    try {
      await _fs.collection("games").doc("board").set(fullBoardData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("초기화 완료! (땅 $landCount개, 그룹 1~8 할당)")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러: $e")));
      }
    }
  }

  // [기능 2] 필드 추가 (기존 + 그룹 필드 없는 경우 0으로 추가)
  Future<void> _addFestivalFields() async {
    try {
      DocumentReference boardRef = _fs.collection("games").doc("board");
      DocumentSnapshot snapshot = await boardRef.get();
      if (!snapshot.exists) return;

      Map<String, dynamic> boardData = snapshot.data() as Map<String, dynamic>;
      int updateCount = 0;

      boardData.forEach((key, val) {
        if (val is Map && val['type'] == 'land') {
          // 기존 필드 보장
          if (val['isFestival'] == null) val['isFestival'] = false;
          if (val['multiply'] == null) val['multiply'] = 1;

          // 💡 그룹 정보가 없으면 기본값 0 추가 (가급적 초기화를 다시 하시는 게 좋습니다)
          if (val['group'] == null) val['group'] = 0;

          updateCount++;
        }
      });
      await boardRef.update(boardData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("총 $updateCount개 필드 갱신 완료!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러: $e")));
    }
  }

  // [기능 3] 개별 수정 (그룹 수정 기능 추가)
  Future<void> _updateSingleBlock() async {
    String key = _keyController.text.trim();
    if (key.isEmpty) return;
    try {
      Map<String, dynamic> data = {
        "index": int.tryParse(_indexController.text) ?? 0,
        "type": _typeController.text,
        "name": _nameController.text.isEmpty ? null : _nameController.text,
        if (_typeController.text == 'land') ...{
          "level": 0,
          "owner": "N",
          "tollPrice": int.tryParse(_tollController.text) ?? 100000,
          "isFestival": false,
          "multiply": 1,
          "group": int.tryParse(_groupController.text) ?? 0, // 💡 그룹 수정 반영
        }
      };
      await _fs.collection("games").doc("board").set({key: data}, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("수정 완료!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러: $e")));
    }
  }

  // [기능 4] 퀴즈 데이터 초기화
  Future<void> _initializeQuizData() async {
    Map<String, dynamic> quizData = {};
    for (int i = 1; i <= 24; i++) {
      String key = 'q$i';
      quizData[key] = {
        'description': null,
        'img': null,
        'name': null,
        'times': null,
      };
    }
    try {
      await _fs.collection("games").doc("quiz").set(quizData);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("퀴즈 데이터(q1~q24) 초기화 완료!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("퀴즈 에러: $e")));
    }
  }

  // [기능 5] 유저 데이터 초기화
  Future<void> _initializeUserData() async {
    Map<String, dynamic> usersData = {};

    for (int i = 1; i <= 4; i++) {
      usersData['user$i'] = {
        'card': "N",
        'level': 1,
        'money': 7000000,
        'totalMoney': 7000000,
        'position': 0,
        'rank': 1,
        'turn': 0,
        'type': "N",
        'double' : 0,
        'islandCount' : 0,
        "isTraveling" : false,
        "restCount" : 0,
        "isDoubleToll" : false
      };
    }

    try {
      await _fs.collection("games").doc("users").set(usersData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("👤 유저(user1~4) 정보 리셋 완료!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("유저 리셋 에러: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("7칸(28) 보드 DB 관리자")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 섹션 1: 보드 초기화
            _buildSectionContainer(
              color: Colors.blue,
              title: "🚀 보드 초기화 (b0~b27)",
              desc: "28칸 레이아웃 + 그룹(1~8) 할당하여 초기화합니다.",
              btnText: "보드 생성하기",
              onPressed: _initializeBoardLayout,
            ),
            const SizedBox(height: 20),

            // 섹션 2: 필드 추가
            _buildSectionContainer(
              color: Colors.orange,
              title: "🎉 필드 갱신",
              desc: "기존 데이터에 빠진 필드(group 등)를 추가합니다.",
              btnText: "필드 갱신하기",
              onPressed: _addFestivalFields,
            ),
            const SizedBox(height: 20),

            // 섹션 3: 퀴즈 초기화
            _buildSectionContainer(
              color: Colors.purple,
              title: "❓ 퀴즈 초기화 (q1~q24)",
              desc: "q1부터 q24까지 빈 퀴즈 데이터를 생성합니다.",
              btnText: "퀴즈 DB 생성하기",
              onPressed: _initializeQuizData,
            ),
            const SizedBox(height: 20),

            // 섹션 4: 유저 초기화
            _buildSectionContainer(
              color: Colors.red,
              title: "👤 유저 초기화 (user1~4)",
              desc: "모든 유저를 출발지, 700만원, 레벨1 상태로 리셋합니다.",
              btnText: "유저 리셋하기",
              onPressed: _initializeUserData,
            ),

            const Divider(height: 40, thickness: 2),
            const Text("🛠️ 개별 블록 수정", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),

            TextField(controller: _keyController, decoration: const InputDecoration(labelText: "DB 키값 (예: b1)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _indexController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "인덱스", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _typeController, decoration: const InputDecoration(labelText: "타입 (land 등)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "이름", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _tollController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "통행료", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _groupController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "그룹 (1~8)", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _updateSingleBlock,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("해당 칸 정보 업데이트"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required MaterialColor color,
    required String title,
    required String desc,
    required String btnText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          Text(desc),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              child: Text(btnText),
            ),
          ),
        ],
      ),
    );
  }
}