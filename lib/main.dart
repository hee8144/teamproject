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

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // [기능 1] 32칸 전체 초기화
  // [기능 1] 32칸 전체 초기화
  Future<void> _initializeBoardLayout() async {
    Map<String, dynamic> fullBoardData = {};

    // [중요] 반드시 for문 밖에서 선언해야 카운트가 누적됩니다.
    int landCount = 0;

    print("--- 통행료 계산 시작 ---"); // 디버깅용 로그

    for (int i = 0; i < 32; i++) {
      String key = "b$i";
      String type = "land";
      String? name;

      // 1. 칸 종류 지정
      if (i == 0) { type = "start"; name = "출발지"; }
      else if (i == 8) { type = "island"; name = "무인도"; }
      else if (i == 16) { type = "festival"; name = "지역축제"; }
      else if (i == 24) { type = "travel"; name = "국내여행"; }
      else if (i == 30) { type = "tax"; name = "국세청"; }
      else if ([4, 12, 20, 28].contains(i)) { type = "chance"; name = "찬스"; }

      Map<String, dynamic> blockData = {
        "index": i,
        "type": type,
        "name": name,
      };

      // 2. 땅(land)일 때만 가격 계산 로직 수행
      if (type == "land") {
        // 계산: 10만원 + (현재까지 나온 땅 개수 * 1만원)
        int calculatedToll = 100000 + (landCount * 10000);

        blockData.addAll({
          "name": "일반 땅 ${landCount + 1}", // DB에서 확인 쉽도록 번호 붙임
          "level": 0,
          "owner": "N",
          "tollPrice": calculatedToll,
          "isFestival": false,
          "multiply": 1,
        });

        // [중요] 디버그 콘솔(Run 탭)에서 이 로그가 찍히는지 확인하세요.
        print("칸번호: $i / 땅순서: $landCount / 가격: $calculatedToll");

        landCount++; // 다음 땅을 위해 카운트 1 증가
      }

      fullBoardData[key] = blockData;
    }

    print("--- 데이터 생성 완료, DB 전송 시작 ---");

    try {
      await _fs.collection("games").doc("board").set(fullBoardData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("초기화 완료! 총 땅 개수: $landCount개")),
        );
      }
    } catch (e) {
      print("에러 발생: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러: $e")));
      }
    }
  }

  // [기능 2] 필드 추가
  Future<void> _addFestivalFields() async {
    try {
      DocumentReference boardRef = _fs.collection("games").doc("board");
      DocumentSnapshot snapshot = await boardRef.get();
      if (!snapshot.exists) return;

      Map<String, dynamic> boardData = snapshot.data() as Map<String, dynamic>;
      int updateCount = 0;

      boardData.forEach((key, val) {
        if (val is Map && val['type'] == 'land') {
          val['isFestival'] = false;
          val['multiply'] = 1;
          updateCount++;
        }
      });
      await boardRef.update(boardData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("총 $updateCount개 필드 추가 완료!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러: $e")));
    }
  }

  // [기능 3] 개별 수정
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
        }
      };
      await _fs.collection("games").doc("board").set({key: data}, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("수정 완료!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러: $e")));
    }
  }

  // ----------------------------------------------------------------------
  // [기능 4] 퀴즈 데이터 초기화 (New)
  // q1 ~ q24 까지 null 값으로 채웁니다.
  // ----------------------------------------------------------------------
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("게임 보드 DB 관리자")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 섹션 1: 보드 초기화
            _buildSectionContainer(
              color: Colors.blue,
              title: "🚀 보드 초기화 (b0~b31)",
              desc: "게임판 32칸을 기본 세팅으로 생성합니다.",
              btnText: "보드 생성하기",
              onPressed: _initializeBoardLayout,
            ),
            const SizedBox(height: 20),

            // 섹션 2: 필드 추가
            _buildSectionContainer(
              color: Colors.orange,
              title: "🎉 축제 필드 추가",
              desc: "기존 land에 isFestival, multiply를 추가합니다.",
              btnText: "필드 추가하기",
              onPressed: _addFestivalFields,
            ),
            const SizedBox(height: 20),

            // 섹션 3: 퀴즈 초기화 (새로 추가됨)
            _buildSectionContainer(
              color: Colors.purple,
              title: "❓ 퀴즈 초기화 (q1~q24)",
              desc: "q1부터 q24까지 빈 퀴즈 데이터를 생성합니다.",
              btnText: "퀴즈 DB 생성하기",
              onPressed: _initializeQuizData,
            ),

            const Divider(height: 40, thickness: 2),
            const Text("🛠️ 개별 블록 수정", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),

            // 입력 폼들
            TextField(controller: _keyController, decoration: const InputDecoration(labelText: "DB 키값 (예: b1)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _indexController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "인덱스", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _typeController, decoration: const InputDecoration(labelText: "타입 (land 등)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "이름", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _tollController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "통행료", border: OutlineInputBorder())),
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

  // 디자인 중복을 줄이기 위한 위젯 헬퍼
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