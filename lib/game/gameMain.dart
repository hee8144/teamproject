import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dice.dart'; // dice.dart 파일이 같은 폴더에 있어야 합니다.
import '../Popup/construction.dart'; // 경로 유지
import '../Popup/TaxDialog.dart'; // 경로 유지

class GameMain extends StatefulWidget {
  const GameMain({super.key});

  @override
  State<GameMain> createState() => _GameMainState();
}

class _GameMainState extends State<GameMain> with TickerProviderStateMixin {

  FirebaseFirestore fs = FirebaseFirestore.instance;
  String localName = "";
  int localcode = 0;
  bool _isLoading = true;
  List<Map<String, String>> heritageList = [];
  Map<String, dynamic> boardList = {};

  String eventNow = "";
  int _eventPlayer = 0;
  int itsFestival = 0; // 페스티벌 로직 유지

  // 💡 턴 관리 변수
  int currentTurn = 1;
  int totalTurn = 30;
  int doubleCount = 0;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  int? _highlightOwner;

  List<Map<String, dynamic>> localList = [
    {'인천': {'ccbaCtcd': 23}},{'세종': {'ccbaCtcd': 45}},{'울산': {'ccbaCtcd': 26}},
    {'제주': {'ccbaCtcd': 50}},{'대구': {'ccbaCtcd': 22}},{'충북': {'ccbaCtcd': 33}},
    {'대전': {'ccbaCtcd': 25}},{'전북': {'ccbaCtcd': 35}},{'강원': {'ccbaCtcd': 32}},
    {'부산': {'ccbaCtcd': 21}},{'충남': {'ccbaCtcd': 35}},{'경기': {'ccbaCtcd': 31}},
    {'경남': {'ccbaCtcd': 38}},{'전남': {'ccbaCtcd': 36}},{'경북': {'ccbaCtcd': 37}},
    {'광주': {'ccbaCtcd': 24}},{'서울': {'ccbaCtcd': 11}}
  ];

  Map<String, dynamic> players = {};

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _setLocal();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // 💡 주사위 굴리기 콜백
  void _onDiceRoll(int val1, int val2) {
    bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;

    if (isTraveling) {
      setState(() {
        players["user$currentTurn"]["isTraveling"] = false;
      });
      fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
      _triggerHighlight(currentTurn, "trip");
      return;
    }

    int total = val1 + val2;
    bool isDouble = (val1 == val2);
    movePlayer(4, currentTurn, isDouble);
  }

  // 💡 턴 시작 시 상태 체크
  void _checkAndStartTurn() {
    String type = players["user$currentTurn"]?["type"] ?? "N";
    if (type == "N") {
      _nextTurn();
      return;
    }

    bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
    if (isTraveling) {
      setState(() {
        players["user$currentTurn"]["isTraveling"] = false;
      });
      fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
      _triggerHighlight(currentTurn, "trip");
    }
  }

  void _triggerHighlight(int player, String event) {
    _eventPlayer = player;
    if(event == "trip"){
      setState(() {
        _highlightOwner = -1; // -1: 전체 맵 빛남
        eventNow = event;
      });
    } else {
      setState(() {
        _highlightOwner = player;
        eventNow = event;
      });
    }
    _glowController.repeat(reverse: true);
  }

  Future<void> _stopHighlight(int index, String event) async {
    setState(() {
      _highlightOwner = null;
    });
    _glowController.stop();
    _glowController.reset();

    if(event == "start"){
      final result = await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context){
            return ConstructionDialog(user: _eventPlayer, buildingId: index);
          }
      );
      if (result != null && result is Map) {
        setState(() {
          if (boardList["b$index"] == null) boardList["b$index"] = {};
          boardList["b$index"]["level"] = result["level"];
          boardList["b$index"]["owner"] = result["user"];
        });
        _setPlayer();
      }
    } else if(event == "festival"){
      // 💡 페스티벌 로직 유지
      if(itsFestival != 0){
        await fs.collection("games").doc("board").update({"b$itsFestival.isFestival" : false});
      }
      await fs.collection("games").doc("board").update({"b$index.isFestival" : true});
      setState(() {
        itsFestival = index;
      });
      await _readLocal();
    } else if (event == "trip"){
      _movePlayerTo(index, _eventPlayer);
    }
  }

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
        _checkAndStartTurn();
      });
    }
  }

  Future<void> _setPlayer() async {
    await _readPlayer();
    await fs.collection("games").doc("users").set(players);
  }

  void _movePlayerTo(int targetIndex, int player) async {
    int currentPos = players["user$player"]["position"];
    int steps = targetIndex - currentPos;
    if (steps < 0) steps += 28;
    movePlayer(steps, player, false);
  }

  void movePlayer(int num, int player, bool isDouble) async {
    int currentPos = players["user$player"]["position"];
    int nextPos = currentPos + num;
    int changePosition = nextPos > 27 ? nextPos % 28 : nextPos;

    if(nextPos > 27){
      int level = players["user$player"]["level"];
      if(level < 4){
        await fs.collection("games").doc("users").update({
          "user$player.level": level + 1,
          "user$player.money": players["user$player"]["money"] + 1000000,
          "user$player.totalMoney": players["user$player"]["totalMoney"] + 1000000
        });
      } else {
        await fs.collection("games").doc("users").update({
          "user$player.money": players["user$player"]["money"] + 1000000,
          "user$player.totalMoney": players["user$player"]["totalMoney"] + 1000000
        });
      }
    }

    setState(() {
      players["user$player"]["position"] = changePosition;
    });

    await fs.collection("games").doc("users").update({"user$player.position": changePosition});

    String tileKey = "b$changePosition";
    bool forceNextTurn = false;

    // --- 도착지 로직 ---
    if(boardList[tileKey] != null && boardList[tileKey]["type"] == "land"){
      final result = await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context){
            return ConstructionDialog(user: player, buildingId: changePosition);
          }
      );
      if (result != null && result is Map) {
        setState(() {
          if (boardList[tileKey] == null) boardList[tileKey] = {};
          boardList[tileKey]["level"] = result["level"];
          boardList[tileKey]["owner"] = result["user"];
        });
      }
    }
    else if(changePosition == 26){ // 국세청
      await showDialog(context: context, builder: (context)=>
          TaxDialog(user: player)
      );
    }
    else if(changePosition == 14){ // 축제
      bool hasMyLand = false;
      boardList.forEach((key, val) {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        if(val['type'] == 'land' && owner == player) {
          hasMyLand = true;
        }
      });

      if(hasMyLand) {
        _triggerHighlight(player, "festival");
      } else {
        forceNextTurn = true;
      }
    }
    else if(changePosition == 0){ // 출발
      bool hasUpgradableLand = false;
      boardList.forEach((key, val) {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        int level = val['level'] ?? 0;
        if(val['type'] == 'land' && owner == player && level < 4) {
          hasUpgradableLand = true;
        }
      });

      if(hasUpgradableLand) {
        _triggerHighlight(player, "start");
      } else {
        forceNextTurn = true;
      }
    }
    else if(changePosition == 21){ // 여행
      setState(() {
        players["user$player"]["isTraveling"] = true;
      });
      await fs.collection("games").doc("users").update({"user$player.isTraveling": true});
      forceNextTurn = true;
    }
    else if(changePosition == 7){ // 무인도
      forceNextTurn = true;
      fs.collection("games").doc("users").update({
        "user$player.islandCount" : 3
      });
    }

    _setPlayer();

    // 💡 턴 넘기기
    if (forceNextTurn || !isDouble) {
      _nextTurn();
    } else {
      doubleCount++;
      if (doubleCount >= 3) {
        setState(() {
          players["user$player"]["position"] = 7;
        });
        await fs.collection("games").doc("users").update({
          "user$player.position": 7,
          "user$player.islandCount": 3
        });
        _nextTurn();
      }
    }
  }

  void _nextTurn() {
    setState(() {
      doubleCount = 0;
      int nextPlayer = currentTurn;
      int safetyLoop = 0;

      // N 타입 건너뛰기
      do {
        if (nextPlayer == 4) {
          nextPlayer = 1;
          totalTurn--;
          if (totalTurn == 0) {
            // 게임 종료 로직
          }
        } else {
          nextPlayer++;
        }
        safetyLoop++;
      } while ((players["user$nextPlayer"]?["type"] ?? "N") == "N" && safetyLoop < 10);

      currentTurn = nextPlayer;
      _checkAndStartTurn();
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

      for (int i = 1; i <= 27; i++) {
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

  Map<String, double> _getTilePosition(int index, double boardSize, double tileSize) {
    double top = 0;
    double left = 0;

    if (index >= 0 && index <= 7) {
      top = boardSize - tileSize;
      left = boardSize - tileSize - (index * tileSize);
    }
    else if (index >= 8 && index <= 14) {
      left = 0;
      top = boardSize - tileSize - ((index - 7) * tileSize);
    }
    else if (index >= 15 && index <= 21) {
      top = 0;
      left = (index - 14) * tileSize;
    }
    else if (index >= 22 && index <= 27) {
      left = boardSize - tileSize;
      top = (index - 21) * tileSize;
    }
    return {'top': top, 'left': left};
  }

  Widget _buildAnimatedPlayer(int playerIndex, double boardSize, double tileSize) {
    String userKey = "user${playerIndex + 1}";

    // N 타입이면 표시 안 함
    String type = players[userKey]?["type"] ?? "N";
    if (type == "N") return const SizedBox();

    int position = players[userKey]?["position"] ?? 0;

    Map<String, double> pos = _getTilePosition(position, boardSize, tileSize);

    double offsetX = (tileSize / 2) - (4 * 11 / 2) + (playerIndex * 11);
    double offsetY = tileSize * 0.7;

    final List<Color> userColors = [Colors.red, Colors.blue, Colors.green, Colors.yellow];

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      top: pos['top']! + offsetY,
      left: pos['left']! + offsetX,
      child: Container(
        width: 10,
        height: 10,
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
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }
    final double screenHeight = MediaQuery.of(context).size.height;
    final double boardSize = screenHeight * 0.8;
    final double tileSize = boardSize / 8;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity, height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(image: AssetImage('assets/board-background.PNG'), fit: BoxFit.cover),
              ),
            ),
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: boardSize * 0.75,
                      height: boardSize * 0.75,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // 💡 [수정됨] 주사위 화면 또는 안내 멘트 위젯 표시
                      child: _highlightOwner == null
                          ? DiceApp(
                        turn: currentTurn,
                        totalTurn: totalTurn,
                        onRoll: (int v1, int v2) => _onDiceRoll(v1, v2),
                      )
                          : _showEventDialog(),
                    ),
                  ),

                  ...List.generate(28, (index) {
                    return _buildGameTile(index, tileSize, boardSize);
                  }),
                  ...List.generate(4, (index) {
                    return _buildAnimatedPlayer(index, boardSize, tileSize);
                  }),
                ],
              ),
            ),
            _buildPlayerInfoPanel(alignment: Alignment.bottomRight, playerData: players['user1'], color: Colors.red, name : "user1"),
            _buildPlayerInfoPanel(alignment: Alignment.topLeft, playerData: players['user2'], color : Colors.blue, name : "user2"),
            _buildPlayerInfoPanel(alignment: Alignment.bottomLeft, playerData: players['user3'], color: Colors.green, name : "user3"),
            _buildPlayerInfoPanel(alignment: Alignment.topRight, playerData: players['user4'], color : Colors.yellow, name : "user4"),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfoPanel({required Alignment alignment, required Map<String, dynamic> playerData, required Color color, required String name}) {
    String type = playerData['type'] ?? "N";

    if (type == "N") return const SizedBox();

    // 💡 봇 이름 변경 로직 유지
    String displayName = name;
    if (type == "B") {
      displayName = "bot";
    }

    bool isTop = alignment.y < 0;
    bool isLeft = alignment.x < 0;
    Color bgColor = color;
    String money = "${playerData['money']}";
    String totalMoney = "${playerData['totalMoney']}";
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
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
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

  // 💡 [추가] 안내 멘트 위젯
  Widget _showEventDialog() {
    String eventText = "";
    if(eventNow == "trip") eventText = "여행갈 땅을 선택해주세요!";
    else if(eventNow == "festival") eventText = "축제가 열릴 땅을 선택해주세요!";
    else if(eventNow == "start") eventText = "건설할 땅을 선택해주세요!";

    // 여행 등 이벤트 발생 시 중앙에 표시될 위젯
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC0A060), width: 4),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.brown),
            const SizedBox(height: 10),
            Text(
              eventText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTile(int index, double size, double boardSize) {
    double? top, bottom, left, right;

    if (index >= 0 && index <= 7) { bottom = 0; right = index * size; }
    else if (index >= 8 && index <= 14) { left = 0; bottom = (index - 7) * size; }
    else if (index >= 15 && index <= 21) { top = 0; left = (index - 14) * size; }
    else if (index >= 22 && index <= 27) { right = 0; top = (index - 21) * size; }

    Color barColor = Colors.grey; IconData? icon; String label = ""; bool isSpecial = false;

    if (index == 0) { label = "출발"; icon = Icons.flag_circle; barColor = Colors.white; isSpecial = true; }
    else if (index == 7) { label = "무인도"; icon = Icons.lock_clock; isSpecial = true; }
    else if (index == 14) { label = "축제"; icon = Icons.celebration; isSpecial = true; }
    else if (index == 21) { label = "여행"; icon = Icons.flight_takeoff; isSpecial = true; }
    else if (index == 26) { label = "국세청"; icon = Icons.account_balance; isSpecial = true; }
    else if ([3, 10, 17, 24].contains(index)) { label = "찬스"; icon = Icons.question_mark_rounded; barColor = Colors.orange; isSpecial = true; }

    else if (index < 3) barColor = const Color(0xFFCFFFE5);
    else if (index < 7) barColor = const Color(0xFF66BB6A);
    else if (index < 10) barColor = const Color(0xFF42A5F5);
    else if (index < 14) barColor = const Color(0xFFAB47BC);
    else if (index < 17) barColor = const Color(0xFFFFEB00);
    else if (index < 21) barColor = const Color(0xFF808080);
    else if (index < 24) barColor = const Color(0xFFFF69B4);
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

  Widget _buildLandContent(Color color, String name, int price, int index) {
    var tileData = boardList["b$index"] ?? {};
    bool isFestival = itsFestival == index; // 💡 페스티벌 로직 유지
    double multiply = (tileData["multiply"] as num? ?? 0).toDouble();
    int buildLevel = tileData["level"] ?? 0;

    int levelvalue = 1;
    switch (buildLevel) {
      case 1: levelvalue = 2; break;
      case 2: levelvalue = 6; break;
      case 3: levelvalue = 14; break;
      case 4: levelvalue = 40; break;
    }
    if (isFestival && multiply == 1) multiply *= 2;

    int tollPrice = (price * multiply * levelvalue).round();

    int level = tileData["level"] ?? 0;
    int owner = int.tryParse(tileData["owner"].toString()) ?? 0;

    final List<Color> ownerColors = [Colors.transparent, Colors.red, Colors.blue, Colors.green, Colors.yellow];
    Color badgeColor = (owner >= 1 && owner <= 4) ? ownerColors[owner] : Colors.transparent;

    bool shouldGlow = false;
    if (_highlightOwner == -1) {
      shouldGlow = true;
    } else if (_highlightOwner != null && _highlightOwner == owner) {
      if (eventNow == "start") {
        if (level < 4) shouldGlow = true;
      } else {
        shouldGlow = true;
      }
    }

    return GestureDetector(
      onTap: () {
        if (shouldGlow) {
          _stopHighlight(index, eventNow);
        } else {
          // 지역 상세정보 보여주기
        }
      },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          double glowValue = _glowAnimation.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 3.0),
                            decoration: BoxDecoration(color: color),
                            child: (multiply != 1)
                                ? Text("X${multiply == multiply.toInt() ? multiply.toInt() : multiply}",
                                style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 6, fontWeight: FontWeight.bold))
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
                                Opacity(
                                  opacity: isFestival ? 0.15 : 0,
                                  child: const Icon(Icons.celebration, size: 30, color: Colors.purple),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (price > 0)
                                      Text("${(tollPrice/10000).floor()}만", style: TextStyle(fontSize: 7, color: Colors.grey[600])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (level > 0)
                      Positioned(
                        top: 0, right: 0,
                        child: ClipPath(
                          clipper: _TopRightTriangleClipper(),
                          child: Container(
                            width: 28, height: 28, color: badgeColor,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(top: 3, right: 5),
                            child: level != 4 ? Text("$level", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (owner == 4) ? Colors.black : Colors.white))
                                : Icon(Icons.star, size: 11, color: (owner == 4) ? Colors.black : Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (shouldGlow)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.8), width: 2.0 + (glowValue * 2.0)),
                      boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.6 * glowValue), blurRadius: 5 + (glowValue * 10), spreadRadius: 2)],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpecialContent(String label, IconData icon, bool isStart, int index) {
    return Container(
      decoration: BoxDecoration(
        color: isStart ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Column(
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

class _TopRightTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(0, 0);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}