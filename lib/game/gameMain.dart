import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dice.dart'; // 위에서 만든 dice.dart 파일 import

class GameMain extends StatefulWidget {
  const GameMain({super.key});

  @override
  State<GameMain> createState() => _GameMainState();
}

class _GameMainState extends State<GameMain> {
  FirebaseFirestore fs = FirebaseFirestore.instance;
  String localName = "";
  int localcode = 0;
  bool _isLoading = true;
  List<Map<String, String>> heritageList = [];
  Map<String, dynamic> boardList = {};

  // 지역 코드 리스트
  List<Map<String, dynamic>> localList = [
    {'인천': {'ccbaCtcd': 23}},{'세종': {'ccbaCtcd': 45}},{'울산': {'ccbaCtcd': 26}},
    {'제주': {'ccbaCtcd': 50}},{'대구': {'ccbaCtcd': 22}},{'충북': {'ccbaCtcd': 33}},
    {'대전': {'ccbaCtcd': 25}},{'전북': {'ccbaCtcd': 35}},{'강원': {'ccbaCtcd': 32}},
    {'부산': {'ccbaCtcd': 21}},{'충남': {'ccbaCtcd': 35}},{'경기': {'ccbaCtcd': 31}},
    {'경남': {'ccbaCtcd': 38}},{'전남': {'ccbaCtcd': 36}},{'경북': {'ccbaCtcd': 37}},
    {'광주': {'ccbaCtcd': 24}},{'서울': {'ccbaCtcd': 11}}
  ];

  Map<String, dynamic> players = {};

  Future<void> _setLocal() async{
    int random = Random().nextInt(localList.length);
    if(mounted) {
      setState(() {
        localName = localList[random].keys.first;
        localcode = localList[random][localName]['ccbaCtcd'];
      });
    }
    var heritage = await _loadHeritage();
    if(mounted) {
      setState(() { heritageList = heritage; });
    }
    var detail = await _loadHeritageDetail();
    if(mounted) {
      setState(() { heritageList = detail; });
    }

    await _insertLocal();
    await _readLocal();
    await _readPlayer();
    await rankChange();

    if(mounted) {
      setState(() { _isLoading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStartDialog(localName);
      });
    }
  }

  // 주사위 수만큼 움직이는 함수 (콜백으로 실행됨)
  void movePlayer(int num, int player){
    setState(() {
      players["user$player"]["position"] += num;
      // 31번 넘어가면 0번으로 순환
      players["user$player"]["position"] %= 32;
    });
  }

  Future<void> rankChange() async{
    int rank = 1;
    for(int i=1; i<=4; i++){
      for(int j=i+1; j<=4; j++){
        if(players["user$i"]["totalMoney"] < players["user$j"]["totalMoney"]){
          rank++;
        }
        players["user$i"]["rank"] = rank;
        rank = 1;
      }
    }
  }

  Future<void> _readPlayer() async{
    final snap = await fs.collection("games").doc("users").get();
    setState(() { players = snap.data() ?? {}; });
  }

  Future<void> _readLocal() async{
    final snap = await fs.collection("games").doc("board").get();
    if(snap.exists && snap.data() != null){
      Map<String, dynamic> boardData = snap.data() as Map<String, dynamic>;
      if(mounted) {
        setState(() { boardList = boardData; });
      }
    }
  }

  Future<void> _insertLocal() async{
    if(heritageList.isEmpty) return;
    for(int i = 1; i<=24; i++) {
      if(i-1 < heritageList.length) {
        await fs.collection("games").doc("quiz").update({
          "q$i.name" : heritageList[i-1]["이름"],
          "q$i.description" : heritageList[i-1]["상세설명"],
          "q$i.times" : heritageList[i-1]["시대"],
          "q$i.img" : heritageList[i-1]["이미지링크"]
        });
      }
    }

    DocumentSnapshot boardSnap = await fs.collection("games").doc("board").get();
    if (boardSnap.exists) {
      Map<String, dynamic> boardData = boardSnap.data() as Map<String, dynamic>;
      Map<String, dynamic> updates = {};
      int heritageIndex = 0;

      for (int i = 1; i <= 31; i++) {
        String key = "b$i";
        if (boardData[key] != null && boardData[key]['type'] == 'land') {
          if (heritageIndex < heritageList.length) {
            updates["$key.name"] = heritageList[heritageIndex]["이름"];
            heritageIndex++;
          }
        }
      }
      if (updates.isNotEmpty) {
        await fs.collection("games").doc("board").update(updates);
      }
    }
  }

  Future<List<Map<String, String>>> _loadHeritageDetail() async{
    final detailList = heritageList.map((item) async{
      final String detailUrl =
          "https://www.khs.go.kr/cha/SearchKindOpenapiDt.do?ccbaKdcd=${item["종목코드"]}&ccbaAsno=${item["관리번호"]}&ccbaCtcd=${item["시도코드"]}";
      try {
        final res = await http.get(Uri.parse(detailUrl));
        if (res.statusCode == 200) {
          final doc = xml.XmlDocument.parse(res.body);
          final detailItem = doc.findAllElements('item').firstOrNull;
          item['상세설명'] = detailItem != null ? getXmlText(detailItem, 'content') : "설명 없음";
          item['이미지링크'] = detailItem != null ? getXmlText(detailItem, 'imageUrl') : "이미지 없음";
          item['시대'] = detailItem != null ? getXmlText(detailItem, 'ccceName') : "시대 없음";
        } else {
          item['상세설명'] = "정보 없음"; item['이미지링크'] = ""; item['시대'] = "";
        }
      } catch (e) {
        item['상세설명'] = "에러"; item['이미지링크'] = ""; item['시대'] = "에러";
      }
      return item;
    });
    return await Future.wait(detailList);
  }

  String getXmlText(xml.XmlElement parent, String tagName) {
    final elements = parent.findElements(tagName);
    return elements.isNotEmpty ? elements.first.innerText.trim() : "";
  }

  Future<List<Map<String, String>>> _loadHeritage() async {
    final String url = "https://www.khs.go.kr/cha/SearchKindOpenapiList.do?ccbaCtcd=$localcode&pageIndex=1&pageUnit=24";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      return items.map((node) => {
        '이름': getXmlText(node, 'ccbaMnm1'),
        '종목코드': getXmlText(node, 'ccbaKdcd'),
        '관리번호': getXmlText(node, 'ccbaAsno'),
        '시도코드': getXmlText(node, 'ccbaCtcd'),
        '시군구명': getXmlText(node, 'ccsiName'),
      }).toList();
    }
    return [];
  }

  void _showStartDialog(String localName) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Future.delayed(const Duration(seconds: 3), () {
          if (context.mounted) Navigator.of(context).pop();
        });
        return AlertDialog(
          title: const Text("게임 시작" ,textAlign: TextAlign.center),
          content: SizedBox(
              width: double.infinity * 0.5,
              child: Text("이번 문화재 보유 지역은\n'$localName' 입니다!", textAlign: TextAlign.center,)
          ),
        );
      },
    );
  }

  // 📍 [애니메이션] 타일 인덱스를 화면 좌표로 변환
  Map<String, double> _getTilePosition(int index, double boardSize, double tileSize) {
    double top = 0;
    double left = 0;

    if (index >= 0 && index <= 8) { // 하단
      top = boardSize - tileSize;
      left = boardSize - tileSize - (index * tileSize);
    } else if (index >= 9 && index <= 16) { // 좌측
      left = 0;
      top = boardSize - tileSize - ((index - 8) * tileSize);
    } else if (index >= 17 && index <= 24) { // 상단
      top = 0;
      left = (index - 16) * tileSize;
    } else if (index >= 25 && index <= 31) { // 우측
      left = boardSize - tileSize;
      top = (index - 24) * tileSize;
    }
    return {'top': top, 'left': left};
  }

  // 🏃‍♂️ [애니메이션] 움직이는 플레이어 위젯
  Widget _buildAnimatedPlayer(int playerIndex, double boardSize, double tileSize) {
    String userKey = "user${playerIndex + 1}";
    int position = players[userKey]?["position"] ?? 0;

    // 타일 위치 가져오기
    Map<String, double> pos = _getTilePosition(position, boardSize, tileSize);

    // 겹치지 않게 미세 조정
    double offsetX = (tileSize / 2) - (4 * 11 / 2) + (playerIndex * 11);
    double offsetY = tileSize * 0.7; // 타일 하단 배치

    final List<Color> userColors = [Colors.red, Colors.blue, Colors.green, Colors.orange];

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500), // 0.5초 동안 부드럽게 이동
      curve: Curves.easeInOut,
      top: pos['top']! + offsetY,
      left: pos['left']! + offsetX,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
            color: userColors[playerIndex],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1,1))]
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _setLocal();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/Logo.png", width: 80,),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Colors.amber),
              const SizedBox(height: 20),
              const Text("문화재 정보를 불러오고 있습니다...", style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }
    final double screenHeight = MediaQuery.of(context).size.height;
    final double boardSize = screenHeight * 0.95;
    final double tileSize = boardSize / 9;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. [배경]
            Container(
              width: double.infinity, height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(image: AssetImage('assets/board-background.PNG'), fit: BoxFit.cover),
              ),
            ),

            // 2. [보드판 영역]
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                children: [
                  // (1) 중앙 주사위 앱
                  Center(
                    child: Container(
                      width: boardSize * 0.75,
                      height: boardSize * 0.75,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // 주사위 앱 연결 (콜백 함수 전달)
                      child: DiceApp(
                        onRoll: (int result, int turn) {
                          movePlayer(result, turn);
                        },
                      ),
                    ),
                  ),

                  // (2) 타일들 (0~31번)
                  ...List.generate(32, (index) {
                    return _buildGameTile(index, tileSize);
                  }),

                  // (3) ★ 애니메이션 플레이어 말 (최상단 레이어)
                  ...List.generate(4, (index) {
                    return _buildAnimatedPlayer(index, boardSize, tileSize);
                  }),
                ],
              ),
            ),

            // 3. [플레이어 정보 패널]
            _buildPlayerInfoPanel(alignment: Alignment.topLeft, playerData: players['user2'], color : Colors.blue, name : "user2"),
            _buildPlayerInfoPanel(alignment: Alignment.topRight, playerData: players['user4'], color : Colors.green, name : "user4"),
            _buildPlayerInfoPanel(alignment: Alignment.bottomLeft, playerData: players['user3'], color: Colors.amber, name : "user3"),
            _buildPlayerInfoPanel(alignment: Alignment.bottomRight, playerData: players['user1'], color: Colors.red, name : "user1"),
          ],
        ),
      ),
    );
  }

  // 플레이어 정보 패널
  Widget _buildPlayerInfoPanel({required Alignment alignment, required Map<String, dynamic> playerData, required Color color, required String name}) {
    bool isTop = alignment.y < 0;
    bool isLeft = alignment.x < 0;
    Color bgColor = color;
    String money = "${(playerData['money'] / 10000).floor()}만원";
    String totalMoney = "${(playerData['totalMoney'] / 10000).floor()}만원";
    int rank = playerData['rank'];

    return Positioned(
      top: isTop ? 0 : null, bottom: isTop ? null : 0,
      left: isLeft ? 0 : null, right: isLeft ? null : 0,
      child: SafeArea(
        minimum: const EdgeInsets.all(10),
        child: SizedBox(
          width: 160, height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 140, height: 70,
                margin: EdgeInsets.only(top: isTop ? 0 : 10, bottom: isTop ? 10 : 0, left: isLeft ? 0 : 20, right: isLeft ? 20 : 0),
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(2,2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text("소지금 : $money", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    Text("총 자산 : $totalMoney", style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
              Positioned(
                top: isTop ? 40 : 0, left: isLeft ? 110 : 0,
                child: Container(
                  width: 40, height: 40, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                  ),
                  child: Text("$rank등", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 타일 디자인 함수
  Widget _buildGameTile(int index, double size) {
    double? top, bottom, left, right;
    if (index >= 0 && index <= 8) { bottom = 0; right = index * size; }
    else if (index >= 9 && index <= 16) { left = 0; bottom = (index - 8) * size; }
    else if (index >= 17 && index <= 24) { top = 0; left = (index - 16) * size; }
    else if (index >= 25 && index <= 31) { right = 0; top = (index - 24) * size; }

    Color barColor = Colors.grey; IconData? icon; String label = ""; bool isSpecial = false;

    if (index == 0) { label = "출발"; icon = Icons.flag_circle; barColor = Colors.white; isSpecial = true; }
    else if (index == 8) { label = "무인도"; icon = Icons.lock_clock; isSpecial = true; }
    else if (index == 16) { label = "축제"; icon = Icons.celebration; isSpecial = true; }
    else if (index == 24) { label = "여행"; icon = Icons.flight_takeoff; isSpecial = true; }
    else if (index == 30) { label = "국세청"; icon = Icons.account_balance; isSpecial = true; }
    else if ([4, 12, 20, 28].contains(index)) { label = "찬스"; icon = Icons.question_mark_rounded; barColor = Colors.orange; isSpecial = true; }
    else if (index < 4) barColor = const Color(0xFFCFFFE5);
    else if (index < 8) barColor = const Color(0xFF66BB6A);
    else if (index < 12) barColor = const Color(0xFF42A5F5);
    else if (index < 16) barColor = const Color(0xFFAB47BC);
    else if (index < 20) barColor = const Color(0xFFFFEB00);
    else if (index < 24) barColor = const Color(0xFF808080);
    else if (index < 28) barColor = const Color(0xFFFF69B4);
    else barColor = const Color(0xFFEF5350);

    String tileName = (boardList["b$index"] != null) ? boardList["b$index"]["name"] ?? "" : "";
    int tollPrice = (boardList["b$index"] != null && boardList["b$index"]["tollPrice"] != null) ? boardList["b$index"]["tollPrice"] : 0;

    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: size, height: size, padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(6.0),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3, offset: const Offset(1, 2))],
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
          ),
          child: isSpecial
              ? _buildSpecialContent(label, icon!, index == 0, index)
              : _buildLandContent(barColor, tileName, tollPrice, index),
        ),
      ),
    );
  }

  // 일반 땅 내부 디자인 (수정됨: 정수/실수 타입안전, 오버플로우 방지 Stack)
  Widget _buildLandContent(Color color, String name, int price, int index) {
    double multiply = (boardList["b$index"]?["multiply"] as num? ?? 0).toDouble();
    int tollPrice = (price * multiply).round();

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(6.0), topRight: Radius.circular(6.0)),
            ),
            child: (multiply != 1)
                ? Text("X${multiply == multiply.toInt() ? multiply.toInt() : multiply}", style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold))
                : null,
          ),
        ),
        Expanded(
          flex: 5,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if(price > 0)
                      Text("${(tollPrice/10000).floor()}만", style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                  ],
                ),
                // 플레이어 점은 여기서 그리지 않고 최상단 Stack에서 그립니다.
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 특수 블록 내부 디자인
  Widget _buildSpecialContent(String label, IconData icon, bool isStart, int index) {
    return Container(
      decoration: BoxDecoration(
        color: isStart ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Column( // Stack 제거하고 심플하게 Column (플레이어 점을 따로 그리므로)
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}