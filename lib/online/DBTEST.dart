import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  /// ================== 유저 데이터 생성 ==================
  Future<void> insertUsers() async {
    try {
      debugPrint("🔥 insertUsers 시작");

      final fs = FirebaseFirestore.instance;
      final roomRef = fs.collection('online').doc('1');

      // 부모 문서 보장
      await roomRef.set({
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final batch = fs.batch();

      final Map<String, Map<String, dynamic>> users = {
        "user01": {
          "card": "shield",
          "double": 0,
          "isDoubleToll": false,
          "isTraveling": false,
          "islandCount": 0,
          "level": 1,
          "money": 7000000,
          "position": 24,
          "rank": 4,
          "restCount": 0,
          "totalMoney": 7000000,
          "turn": 0,
          "type": "P",
        },
        "user02": {
          "card": "N",
          "double": 0,
          "isDoubleToll": true,
          "isTraveling": false,
          "islandCount": 0,
          "level": 1,
          "money": 10000000,
          "position": 0,
          "rank": 1,
          "restCount": 0,
          "totalMoney": 10000000,
          "turn": 0,
          "type": "P",
        },
        "user03": {
          "card": "N",
          "double": 0,
          "isDoubleToll": false,
          "isTraveling": false,
          "islandCount": 0,
          "level": 2,
          "money": 7610000,
          "position": 17,
          "rank": 3,
          "restCount": 0,
          "totalMoney": 8000000,
          "turn": 0,
          "type": "P",
        },
        "user04": {
          "card": "shield",
          "double": 0,
          "isDoubleToll": false,
          "isTraveling": false,
          "islandCount": 0,
          "level": 3,
          "money": 7920000,
          "position": 12,
          "rank": 2,
          "restCount": 0,
          "totalMoney": 9000000,
          "turn": 0,
          "type": "P",
        },
      };

      users.forEach((userId, data) {
        batch.set(
          roomRef.collection('users').doc(userId),
          {
            ...data,
            'joinedAt': FieldValue.serverTimestamp(),
            'isOnline': true,
          },
        );
      });

      await batch.commit();

      debugPrint("✅ 유저 데이터 생성 완료");
    } catch (e, s) {
      debugPrint("❌ 유저 생성 에러 발생");
      debugPrint(e.toString());
      debugPrint(s.toString());
    }
  }

  /// ================== 보드 데이터 생성 ==================
  Future<void> insertBoard() async {
    try {
      debugPrint("🔥 insertBoard 시작");

      final fs = FirebaseFirestore.instance;
      final roomRef = fs.collection('online').doc('1');

      // 부모 문서 보장
      await roomRef.set({
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final batch = fs.batch();

      // board 데이터
      final Map<String, Map<String, dynamic>> board = {
        "b0": {"index":0,"name":"출발지","type":"start"},
        "b1": {"group":1,"index":1,"isFestival":false,"level":0,"multiply":1,"name":"제주 관덕정","owner":"N","tollPrice":100000,"type":"land"},
        "b2": {"group":1,"index":2,"isFestival":false,"level":3,"multiply":1,"name":"김정희 종가 유물 일괄","owner":4,"tollPrice":110000,"type":"land"},
        "b3": {"index":3,"name":"찬스","type":"chance"},
        "b4": {"group":2,"index":4,"isFestival":false,"level":3,"multiply":1,"name":"안중근의사 유묵 - 천여불수반수기앙이","owner":3,"tollPrice":120000,"type":"land"},
        "b5": {"group":2,"index":5,"isFestival":false,"level":1,"multiply":1,"name":"제주 불탑사 오층석탑","owner":3,"tollPrice":130000,"type":"land"},
        "b6": {"group":2,"index":6,"isFestival":false,"level":0,"multiply":1,"name":"동여비고","owner":"N","tollPrice":140000,"type":"land"},
        "b7": {"index":7,"name":"무인도","type":"island"},
        "b8": {"group":3,"index":8,"isFestival":false,"level":0,"multiply":1,"name":"제주향교 대성전","owner":"N","tollPrice":150000,"type":"land"},
        "b9": {"group":3,"index":9,"isFestival":false,"level":0,"multiply":1,"name":"이익태 지영록","owner":"N","tollPrice":160000,"type":"land"},
        "b10": {"index":10,"name":"찬스","type":"chance"},
        "b11": {"group":4,"index":11,"isFestival":false,"level":0,"multiply":1,"name":"제주 삼성혈","owner":"N","tollPrice":170000,"type":"land"},
        "b12": {"group":4,"index":12,"isFestival":false,"level":4,"multiply":1,"name":"제주목 관아","owner":4,"tollPrice":180000,"type":"land"},
        "b13": {"group":4,"index":13,"isFestival":false,"level":0,"multiply":1,"name":"제주 항파두리 항몽 유적","owner":"N","tollPrice":190000,"type":"land"},
        "b14": {"index":14,"name":"지역축제","type":"festival"},
        "b15": {"group":5,"index":15,"isFestival":false,"level":3,"multiply":1,"name":"제주 고산리 유적","owner":3,"tollPrice":200000,"type":"land"},
        "b16": {"group":5,"index":16,"isFestival":false,"level":3,"multiply":1,"name":"제주 삼양동 유적","owner":4,"tollPrice":210000,"type":"land"},
        "b17": {"index":17,"name":"찬스","type":"chance"},
        "b18": {"group":6,"index":18,"isFestival":false,"level":3,"multiply":1,"name":"서귀포 김정희 유배지","owner":3,"tollPrice":220000,"type":"land"},
        "b19": {"group":6,"index":19,"isFestival":false,"level":0,"multiply":1,"name":"제주 용담동 유적","owner":"N","tollPrice":230000,"type":"land"},
        "b20": {"group":6,"index":20,"isFestival":false,"level":1,"multiply":1,"name":"제주 서귀포 정방폭포","owner":2,"tollPrice":240000,"type":"land"},
        "b21": {"index":21,"name":"국내여행","type":"travel"},
        "b22": {"group":7,"index":22,"isFestival":false,"level":3,"multiply":1,"name":"제주 서귀포 산방산","owner":1,"tollPrice":250000,"type":"land"},
        "b23": {"group":7,"index":23,"isFestival":false,"level":0,"multiply":1,"name":"제주 서귀포 쇠소깍","owner":"N","tollPrice":260000,"type":"land"},
        "b24": {"index":24,"name":"찬스","type":"chance"},
        "b25": {"group":8,"index":25,"isFestival":false,"level":3,"multiply":1,"name":"제주 서귀포 외돌개","owner":3,"tollPrice":270000,"type":"land"},
        "b26": {"index":26,"name":"국세청","type":"tax"},
        "b27": {"group":8,"index":27,"isFestival":false,"level":0,"multiply":1,"name":"사라오름","owner":"N","tollPrice":280000,"type":"land"},
      };

      board.forEach((boardId, data) {
        batch.set(
          roomRef.collection('board').doc(boardId),
          data,
        );
      });

      await batch.commit();

      debugPrint("✅ 보드 데이터 생성 완료");
    } catch (e, s) {
      debugPrint("❌ 보드 생성 에러 발생");
      debugPrint(e.toString());
      debugPrint(s.toString());
    }
  }

  Future<void> insertQuiz() async {
    try {
      debugPrint("🔥 online/1 문서 내 quiz 필드 업데이트 시작");
      final fs = FirebaseFirestore.instance;
      final roomRef = fs.collection('online').doc('1');

      // 24개 전체 데이터를 하나의 Map으로 묶음
      final Map<String, Map<String, dynamic>> quizMap = {
        "q1": {
          "description": "자장율사가 창건한 월정사 안에 있는 탑으로...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/1612067.jpg",
          "name": "평창 월정사 팔각 구층석탑",
          "times": "고려시대"
        },
        "q2": {
          "description": "고려시대에 지은 강릉 객사의 정문으로...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/1612074.jpg",
          "name": "강릉 임영관 삼문",
          "times": "고려시대 후기"
        },
        "q3": {
          "description": "법천사터에 세워져 있는 지광국사(984∼1070)의 탑비로...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/1612093.jpg",
          "name": "원주 법천사지 지광국사탑비",
          "times": "고려시대"
        },
        "q4": {
          "description": "진전사의 옛터에 서 있는 3층 석탑이다...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/1612117.jpg",
          "name": "양양 진전사지 삼층석탑",
          "times": "통일신라시대"
        },
        "q5": {
          "description": "원래 강원특별자치도 강릉시 한송사 절터에 있던 보살상으로...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/1611567.jpg",
          "name": "강릉 한송사지 석조보살좌상",
          "times": "고려시대"
        },
        "q6": {
          "description": "세조 10년(1464) 세조의 왕사인 혜각존자 신미 등이...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/1612135.jpg",
          "name": "평창 상원사 중창권선문",
          "times": "조선 세조 10년(1464)"
        },
        "q7": {
          "description": "수마노탑은 기단에서 상륜부까지 완전한 모습을 갖추고 있는 모전석탑으로...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/2020062509423800.jpg",
          "name": "정선 정암사 수마노탑",
          "times": "고려시대"
        },
        "q8": {
          "description": "삼척 죽서루는 고려 명종(1171∼1197)대에 활동하였던 김극기가...",
          "img": "http://www.khs.go.kr/unisearch/images/national_treasure/2023122810443300.JPG",
          "name": "삼척 죽서루",
          "times": "조선시대"
        },
        "q9": {
          "description": "조선 숙종 때 경기도와 경상도 지역에서 활동한 승려인 사인비구에 의해서...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616241.jpg",
          "name": "사인비구 제작 동종 - 홍천 수타사 동종",
          "times": "조선 현종 11년(1670)"
        },
        "q10": {
          "description": "당간지주는 사찰 입구에 세워두는 것으로, 절에 행사가 있을 때...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616243.jpg",
          "name": "춘천 근화동 당간지주",
          "times": "고려시대"
        },
        "q11": {
          "description": "춘천 시가지 중심에 자리잡고 있는 탑이다. 조선 인조 때...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616253.jpg",
          "name": "춘천 칠층석탑",
          "times": "고려시대"
        },
        "q12": {
          "description": "거돈사터에 세워져 있는 탑비로, 고려시대의 스님인 원공국사의 행적을...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616262.jpg",
          "name": "원주 거돈사지 원공국사탑비",
          "times": "고려시대"
        },
        "q13": {
          "description": "절에 행사가 있을 때, 절 입구에 당(幢)이라는 깃발을 달아두는데...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616276.jpg",
          "name": "홍천 희망리 당간지주",
          "times": "고려시대"
        },
        "q14": {
          "description": "강릉 시내에 남아 있으며 주변에서 기와조각 등이 출토되어...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616285.jpg",
          "name": "강릉 대창리 당간지주",
          "times": "통일신라시대"
        },
        "q15": {
          "description": "현재 강릉시 옥천동에 자리잡고 있으며, 일대가 절터로 추정되나...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616292.jpg",
          "name": "강릉 수문리 당간지주",
          "times": "통일신라시대"
        },
        "q16": {
          "description": "강원특별자치도 강릉시에 있는 신복사는 통일신라 문성왕 12년에...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616303.jpg",
          "name": "강릉 신복사지 석조보살좌상",
          "times": "고려시대"
        },
        "q17": {
          "description": "이 승탑은 고려시대에 굴산사를 세운 범일국사의 사리를 모신 탑으로...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616319.jpg",
          "name": "강릉 굴산사지 승탑",
          "times": "고려시대"
        },
        "q18": {
          "description": "신라 문성왕 9년 범일국사가 창건한 굴산사의 옛터에 있는...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616342.jpg",
          "name": "강릉 굴산사지 당간지주",
          "times": "통일신라시대"
        },
        "q19": {
          "description": "신복사의 옛 터에 남아있는 탑이다. 통일신라 때 범일국사가 창건한...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616355.jpg",
          "name": "강릉 신복사지 삼층석탑",
          "times": "고려시대"
        },
        "q20": {
          "description": "신사임당(1504∼1551)과 율곡 이이(1536∼1584)가 태어난 집이다...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616387.jpg",
          "name": "강릉 오죽헌",
          "times": "조선 중종"
        },
        "q21": {
          "description": "해운정은 조선 상류주택의 별당 건물로 경포호가 멀리 바라다 보이는...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616406.jpg",
          "name": "강릉 해운정",
          "times": "조선 중종 25년(1530)"
        },
        "q22": {
          "description": "보현사에 자리하고 있는 낭원대사의 사리탑으로, 8각의 평면을 기본으로...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616419.jpg",
          "name": "강릉 보현사 낭원대사탑",
          "times": "고려시대"
        },
        "q23": {
          "description": "보현사에 남아 있는 낭원대사(834∼930)의 탑비로, 대사의 출생에서부터...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616434.jpg",
          "name": "강릉 보현사 낭원대사탑비",
          "times": "고려시대"
        },
        "q24": {
          "description": "강릉향교는 옛 성현께 제사를 드리고 학문을 갈고 닦는 곳으로...",
          "img": "http://www.khs.go.kr/unisearch/images/treasure/1616478.jpg",
          "name": "강릉향교 대성전",
          "times": "조선 태종 13년(1413)"
        },
      };

      // update()를 사용하여 online/1 문서에 'quiz' 필드(Map)를 추가/덮어쓰기 합니다.
      await roomRef.update({'quiz': quizMap});

      debugPrint("✅ online/1 문서 내 quiz 필드 업데이트 완료!");
    } catch (e) { debugPrint("❌ 퀴즈 업데이트 에러: $e"); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("메인")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: insertUsers,
              child: const Text("유저 데이터 생성"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: insertBoard,
              child: const Text("보드 데이터 생성"),
            ),
            ElevatedButton(
              onPressed: insertQuiz,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text("전체 퀴즈(24개) 생성"),
            ),
          ],
        ),
      ),
    );
  }
}
