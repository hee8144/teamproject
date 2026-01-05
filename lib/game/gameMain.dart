import 'dart:async'; // 💡 StreamSubscription을 위해 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../Popup/warning.dart';
import 'dice.dart'; // diceAppKey, DiceApp import
import '../Popup/construction.dart';
import '../Popup/TaxDialog.dart';
import '../Popup/Bankruptcy.dart';
import '../Popup/Takeover.dart';
import '../Popup/Island.dart';
import '../Popup/BoardDetail.dart';
import '../Popup/Detail.dart';
import '../Popup/CardUse.dart';
import '../Popup/check.dart';
import '../quiz/quiz_repository.dart';
import '../quiz/quiz_question.dart';
import '../quiz/quiz_dialog.dart';
import '../quiz/quiz_result_popup.dart';
import '../quiz/chance_card_quiz_after.dart';
import '../quiz/DiscountQuizManager.dart';

class GameMain extends StatefulWidget {
  const GameMain({super.key});

  @override
  State<GameMain> createState() => _GameMainState();
}

class _GameMainState extends State<GameMain> with TickerProviderStateMixin {
  FirebaseFirestore fs = FirebaseFirestore.instance;

  // 💡 실시간 DB 감지를 위한 스트림 구독 변수
  StreamSubscription<DocumentSnapshot>? _boardStream;

  String localName = "";
  int localcode = 0;
  bool _isLoading = true;
  List<Map<String, String>> heritageList = [];
  Map<String, dynamic> boardList = {};

  String eventNow = "";
  int _eventPlayer = 0;
  int itsFestival = 0;

  int currentTurn = 1;
  int totalTurn = 20;
  int doubleCount = 0;

  bool _lastIsDouble = false;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  int? _highlightOwner;

  // 💡 돈 변화 이펙트
  Map<String, String?> _moneyEffects = {};

  List<Map<String, dynamic>> localList = [
    {'인천': {'ccbaCtcd': 23}},{'세종': {'ccbaCtcd': 45}},{'울산': {'ccbaCtcd': 26}},
    {'제주': {'ccbaCtcd': 50}},{'대구': {'ccbaCtcd': 22}},{'충북': {'ccbaCtcd': 33}},
    {'전북': {'ccbaCtcd': 35}},{'강원': {'ccbaCtcd': 32}},
    {'부산': {'ccbaCtcd': 21}},{'충남': {'ccbaCtcd': 35}},{'경기': {'ccbaCtcd': 31}},
    {'경남': {'ccbaCtcd': 38}},{'전남': {'ccbaCtcd': 36}},{'경북': {'ccbaCtcd': 37}},
    {'광주': {'ccbaCtcd': 24}},{'서울': {'ccbaCtcd': 11}}
  ];

  Map<String, dynamic> players = {};

  // 💰 [추가] 숫자 3자리마다 콤마 찍어주는 함수
  String _formatMoney(dynamic number) {
    if (number == null) return "0";
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},');
  }

  Future<void> showWarningIfNeeded(BuildContext context) async {
    final checker = WarningChecker();
    final result = await checker.check();


    if (result == null) return; // 🔥 조건 불충족 → 아무 것도 안 함

    if(result != null){
     if(WarningDialog.canShow(result.players,result.type)){
       showDialog(
         context: context,
         barrierColor: Colors.transparent,
         builder: (_) => WarningDialog(
           players: result.players,
           type: result.type,
         ),
       );
     }
    }
  }



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

    // 💡 [추가] 보드 데이터 실시간 리스너 연결 (DB 수정 시 즉시 반영)
    _boardStream = fs.collection("games").doc("board").snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        if(mounted) {
          setState(() {
            boardList = snapshot.data() as Map<String, dynamic>;
          });
        }
      }
    });

    _setLocal();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _boardStream?.cancel(); // 💡 리스너 해제 (메모리 누수 방지)
    super.dispose();
  }

  void _triggerMoneyEffect(String userKey, int amount) {
    setState(() {
      _moneyEffects[userKey] = amount > 0 ? "+$amount" : "$amount";
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _moneyEffects[userKey] = null;
        });
      }
    });
  }

  Future<void> _onDiceRoll(int val1, int val2) async {
    // 여행 중 체크 (혹시 몰라 유지)
    bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
    if (isTraveling) {
      setState(() {
        players["user$currentTurn"]["isTraveling"] = false;
      });
      await fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
      _triggerHighlight(currentTurn, "trip");
      return;
    }

    int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

    // 🏝️ 무인도 탈출 로직 (봇/사람 공통)
    if (islandCount > 0) {
      bool isDouble = (val1 == val2);

      if (isDouble) {
        // 🎉 탈출 성공!
        print("🎲 더블! 무인도 탈출 성공!");
        await fs.collection("games").doc("users").update({
          "user$currentTurn.islandCount": 0
        });
        setState(() {
          players["user$currentTurn"]["islandCount"] = 0;
        });

        // 이동 (더블 효과로 한 번 더 던지는 건 보통 무인도 탈출 턴엔 안 줌, false 전달)
        movePlayer(val1 + val2, currentTurn, false);
      } else {
        // 🔒 탈출 실패
        print("🎲 더블 아님. 무인도 잔류.");
        int newCount = islandCount - 1;

        // 횟수 다 차면 다음 턴엔 자동 석방? (보통 0되면 다음턴 이동 가능)
        // 여기선 단순히 줄이기만 하고 턴 넘김
        await fs.collection("games").doc("users").update({
          "user$currentTurn.islandCount": newCount
        });
        setState(() {
          players["user$currentTurn"]["islandCount"] = newCount;
        });

        _nextTurn();
      }
      return; // 무인도 처리했으니 함수 종료
    }

    // 일반 이동
    int total = val1 + val2;
    bool isDouble = (val1 == val2);
    movePlayer(total, currentTurn, isDouble);
  }

  Future<void> _checkAndStartTurn() async {
    String type = players["user$currentTurn"]?["type"] ?? "N";

    // 1. 파산자 체크
    if (type == "N" || type == "D" || type == "BD") {
      _nextTurn();
      return;
    }
    await _checkWinCondition(currentTurn);

    // 2. 보드판 배수 초기화 (내 땅 도착 시)
    bool needUpdate = false;
    WriteBatch batch = fs.batch();

    boardList.forEach((key, val) {
      if (val is Map && val['type'] == 'land') {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        double multiply = (val['multiply'] as num? ?? 1.0).toDouble();

        if (owner == currentTurn && multiply < 1.0) {
          batch.update(fs.collection("games").doc("board"), {
            "$key.multiply": 1
          });
          val['multiply'] = 1;
          needUpdate = true;
        }
      }
    });

    if (needUpdate) {
      await batch.commit();
      setState(() {});
    }

    // 3. 쉬어가기 (restCount) 체크
    int restCount = players["user$currentTurn"]["restCount"] ?? 0;

    if (restCount > 0) {
      await fs.collection("games").doc("users").update({
        "user$currentTurn.restCount": 0
      });
      setState(() {
        players["user$currentTurn"]["restCount"] = 0;
      });

      if (type != "B") {
        await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              Future.delayed(const Duration(seconds: 2), () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              });

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
                      const Text(
                        "한턴 쉬어갑니다~",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      _nextTurn();
      return;
    }

    // 4. 무인도 (islandCount) 체크
    int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

    if (islandCount > 0) {
      // 👤 사람일 경우: 탈출 시도 (카드 사용 or 돈 지불)
      if (type != 'B') {
        if(players["user$currentTurn"]["card"] == "escape"){
          final result = await showDialog(context: context, builder: (context)=>CardUseDialog(user: currentTurn));
          if(result) {
            fs.collection("games").doc("users").update({
              "user$currentTurn.card" : "N"
            });
            await _readPlayer();
            return;
          }
        }
        final bool? paidToEscape = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => IslandDialog(user: currentTurn)
        );

        if (paidToEscape == true) {
          await fs.collection("games").doc("users").update({
            "user$currentTurn.islandCount": 0
          });
          setState(() {
            players["user$currentTurn"]["islandCount"] = 0;
          });
          // 돈 내고 탈출했으면 아래쪽 주사위 굴리기로 진행
        }
      }
      // 🤖 봇일 경우: 여기서 아무것도 안 하고 아래로 흘려보냄 -> 주사위 굴려서 탈출 시도
      else {
        print("🤖 봇 무인도 탈출 시도 (주사위 굴림)");
      }
    }

    // 5. 여행 중 체크
    bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
    if (isTraveling) {
      setState(() {
        players["user$currentTurn"]["isTraveling"] = false;
      });
      await fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
      _triggerHighlight(currentTurn, "trip");
      return;
    }

    // 6. 🤖 봇 주사위 굴리기 (무인도여도 실행됨 -> _onDiceRoll에서 결과 처리)
    if (type == "B") {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        int d1 = Random().nextInt(6) + 1;
        int d2 = Random().nextInt(6) + 1;
        (diceAppKey.currentState as dynamic)?.rollDiceForBot(d1, d2);
      });
      return;
    }
  }

  void _triggerHighlight(int player, String event) {
    _eventPlayer = player;
    if(event == "trip" || event == "earthquake"){
      setState(() {
        _highlightOwner = -1;
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
      // 💡 [수정] 레벨 체크 (내 레벨 > 건물 레벨)
      int myLevel = players["user$_eventPlayer"]["level"] ?? 1;
      int buildingLevel = boardList["b$index"]["level"] ?? 0;

      if (myLevel > buildingLevel) {
        final result = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return ConstructionDialog(user: _eventPlayer, buildingId: index);
            }
        );
        if (result != null && result is Map) {
          setState(() {
            String tileKey = "b$index";
            if (boardList[tileKey] == null) boardList[tileKey] = {};
            boardList[tileKey]["level"] = result["level"];
            boardList[tileKey]["owner"] = result["user"];
          });

          await _checkWinCondition(_eventPlayer);
        }
      }

      await _readPlayer();
      await rankChange();
      setState(() {});

      _handleTurnEnd();

    } else if(event == "festival"){
      if(itsFestival != 0){
        await fs.collection("games").doc("board").update({"b$itsFestival.isFestival" : false});
      }
      await fs.collection("games").doc("board").update({"b$index.isFestival" : true});
      setState(() {
        itsFestival = index;
      });
      await _readLocal();
      _handleTurnEnd();

    } else if (event == "trip"){
      // 💡 [수정] 이동하기 전에 안전 장치로 DB에 한번 더 false 저장
      if (players["user$_eventPlayer"]["isTraveling"] == true) {
        setState(() {
          players["user$_eventPlayer"]["isTraveling"] = false;
        });
        await fs.collection("games").doc("users").update({
          "user$_eventPlayer.isTraveling": false
        });
      }

      _movePlayerTo(index, _eventPlayer);

    } else if (event == "earthquake") {
      await _executeEarthquake(index);
      _handleTurnEnd();

    } else if (event == "storm") {
      await _executeEarthquake(index);
      _handleTurnEnd();

    }
    else if (event == "priceDown") {
      await fs.collection("games").doc("board").update({
        "b$index.multiply": 0.5
      });

      setState(() {
        if(boardList["b$index"] != null) {
          boardList["b$index"]["multiply"] = 0.5;
        }
      });

      _handleTurnEnd();
    }
  }

  Future<void> _executeEarthquake(int targetIndex) async {
    String tileKey = "b$targetIndex";
    if (boardList[tileKey] == null) return;

    int currentLevel = boardList[tileKey]["level"] ?? 0;
    final batch = fs.batch();
    final boardRef = fs.collection("games").doc("board");

    if (currentLevel <= 1) {
      batch.update(boardRef, {
        "$tileKey.level": 0,
        "$tileKey.owner": "N",
        "$tileKey.multiply": 1,
        "$tileKey.isFestival": false,
      });
      setState(() {
        boardList[tileKey]["level"] = 0;
        boardList[tileKey]["owner"] = "N";
        boardList[tileKey]["isFestival"] = false;
      });
    } else {
      batch.update(boardRef, {
        "$tileKey.level": currentLevel - 1,
      });
      setState(() {
        boardList[tileKey]["level"] = currentLevel - 1;
      });
    }
    await batch.commit();
    await _readLocal();
    print("지진/태풍 발생! $targetIndex번 땅 공격 완료.");
  }

  Future<void> _checkWinCondition(int player) async {
    print("승리조건체크");
    await showWarningIfNeeded(context);
    int ownedGroups = 0;
    for (int g = 1; g <= 8; g++) {
      List<Map<String, dynamic>> groupTiles = [];
      boardList.forEach((key, val) {
        if (val is Map && val['group'] == g && val['type'] == 'land') {
          groupTiles.add(val as Map<String, dynamic>);
        }
      });

      if (groupTiles.isNotEmpty) {
        bool allMine = groupTiles.every((tile) =>
        int.tryParse(tile['owner'].toString()) == player
        );
        if (allMine) ownedGroups++;
      }
    }

    if (ownedGroups >= 3) {
      _gameOver("triple_monopoly", winnerIndex: player);
      return;
    }

    List<List<int>> lines = [
      [0, 7],   // 1라인
      [7, 14],  // 2라인
      [14, 21], // 3라인
      [21, 28]  // 4라인
    ];

    for (var line in lines) {
      bool lineMonopoly = true;
      bool hasLand = false;

      for (int i = line[0]; i < line[1]; i++) {
        var tile = boardList["b$i"];
        if (tile != null && tile['type'] == 'land') {
          hasLand = true;
          if (int.tryParse(tile['owner'].toString()) != player) {
            lineMonopoly = false;
            break;
          }
        }
      }

      if (hasLand && lineMonopoly) {
        _gameOver("line_monopoly", winnerIndex: player);
        return;
      }
    }
  }

  void _handleTurnEnd() async {
    if (_lastIsDouble) {
      doubleCount++;
      if (doubleCount >= 3) {
        setState(() {
          players["user$_eventPlayer"]["position"] = 7;
          players["user$_eventPlayer"]["islandCount"] = 3;
        });
        await fs.collection("games").doc("users").update({
          "user$_eventPlayer.position": 7,
          "user$_eventPlayer.islandCount": 3
        });
        _nextTurn();
      }
    } else {
      _nextTurn();
    }
  }

  Future<void> _setLocal() async {
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
    await _readLocal(); // 스트림이 있어도 초기 로딩용으로 유지
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
    await rankChange();
    await fs.collection("games").doc("users").set(players);
    await _readPlayer();
  }

  void _movePlayerTo(int targetIndex, int player) async {
    int currentPos = players["user$player"]["position"];
    int steps = targetIndex - currentPos;
    if (steps < 0) steps += 28;
    movePlayer(steps, player, false);
  }


  void movePlayer(int steps, int player, bool isDouble) async {
    _lastIsDouble = isDouble;
    String playerType = players["user$player"]["type"] ?? "P";

    int currentPos = players["user$player"]["position"];
    int nextPos = currentPos + steps;
    int changePosition = nextPos > 27 ? nextPos % 28 : nextPos;

    // 출발지 경유/도착 시 월급 및 레벨업 로직
    if(nextPos > 27){
      int level = players["user$player"]["level"];
      int currentMoney = players["user$player"]["money"];
      int currentTotalMoney = players["user$player"]["totalMoney"];

      int salary = 1000000;

      if(level < 4){
        await fs.collection("games").doc("users").update({
          "user$player.level": level + 1,
          "user$player.money": currentMoney + salary,
          "user$player.totalMoney": currentTotalMoney + salary
        });

        setState(() {
          players["user$player"]["level"] = level + 1;
          players["user$player"]["money"] = currentMoney + salary;
          players["user$player"]["totalMoney"] = currentTotalMoney + salary;
        });
      } else {
        await fs.collection("games").doc("users").update({
          "user$player.money": currentMoney + salary,
          "user$player.totalMoney": currentTotalMoney + salary
        });

        setState(() {
          players["user$player"]["money"] = currentMoney + salary;
          players["user$player"]["totalMoney"] = currentTotalMoney + salary;
        });
      }
    }

    setState(() {
      players["user$player"]["position"] = changePosition;
    });

    await fs.collection("games").doc("users").update({"user$player.position": changePosition});

    String tileKey = "b$changePosition";
    bool forceNextTurn = false;

    // 1. 일반 땅 (건설/인수/통행료)
    if(boardList[tileKey] != null && boardList[tileKey]["type"] == "land"){
      int owner = int.tryParse(boardList[tileKey]["owner"].toString()) ?? 0;
      int buildLevel = boardList[tileKey]["level"] ?? 0;
      int tollPrice = boardList[tileKey]["tollPrice"] ?? 0;

      if(owner == player) {
        if (playerType == 'B') {
          await _botBuild(player, changePosition);
        }
        else {
          int myLevel = players["user$player"]["level"] ?? 1;
          int currentBuildingLevel = (boardList[tileKey] != null) ? (boardList[tileKey]["level"] ?? 0) : 0;

          if (myLevel > currentBuildingLevel) {
            final result = await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return ConstructionDialog(user: player, buildingId: changePosition);
                }
            );
            if (result != null && result is Map) {
              setState(() {
                if (boardList[tileKey] == null) boardList[tileKey] = {};
                boardList[tileKey]["level"] = result["level"];
                boardList[tileKey]["owner"] = result["user"];
              });
              await _readPlayer();
              await _checkWinCondition(player);
            }
          }
        }
      }
      else if(owner != 0 && owner != player) {
        bool isShieldUsed = false;

        // 실드 카드 체크 (봇은 사용 안 함, 사람만)
        if(playerType != 'B' && players["user$player"]["card"] == "shield"){
          final bool? useShield = await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => CardUseDialog(user: player)
          );

          if(useShield == true){
            isShieldUsed = true;
            await fs.collection("games").doc("users").update({
              "user$player.card" : "N"
            });
            setState(() {
              players["user$player"]["card"] = "N";
            });
          }
        }

        int basePrice = boardList[tileKey]["tollPrice"] ?? 0;
        double multiply = (boardList[tileKey]["multiply"] as num? ?? 0).toDouble();
        if(itsFestival == changePosition && multiply == 1) multiply *= 2;
        int levelMulti = 1;

        if (buildLevel == 0) {
          levelMulti = 0;
        } else {
          switch (buildLevel) {
            case 1: levelMulti = 2; break;
            case 2: levelMulti = 6; break;
            case 3: levelMulti = 14; break;
            case 4: levelMulti = 30; break;
          }
        }

        int finalToll = (basePrice * multiply * levelMulti).round();

        bool isDoubleToll = players["user$player"]["isDoubleToll"] ?? false;
        if (isDoubleToll) {
          finalToll *= 2;
        }

        // 퀴즈 할인 (봇 아님 & 실드 안씀)
        if (playerType != 'B' && !isShieldUsed) {
          bool quizResult = await DiscountQuizManager.startDiscountQuiz(context, "통행료");
          if (quizResult) {
            finalToll = (finalToll / 2).round();
          }
        }

        if (isShieldUsed) finalToll = 0;

        int myMoney = players["user$player"]["money"];
        int myTotal = players["user$player"]["totalMoney"];
        int ownerMoney = players["user$owner"]["money"];
        int ownerTotal = players["user$owner"]["totalMoney"];

        if(finalToll > 0) {
          if(myMoney - finalToll < 0){
            bool isBankrupt = false;

            if (playerType == 'B') {
              isBankrupt = true;
            } else {
              final result = await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return BankruptDialog(lackMoney: finalToll - myMoney, reason: "toll", user: player);
                  }
              );
              await _readPlayer();
              if (result != null && result is Map && result["result"] == "BANKRUPT") {
                isBankrupt = true;
              } else if (result == "SURVIVED") {
                await _readPlayer();
                myMoney = players["user$player"]["money"];
                myTotal = players["user$player"]["totalMoney"];
              }
            }

            if (isBankrupt) {
              int remainingMoney = myMoney > 0 ? myMoney : 0;
              int survivorCount = 0;
              for(int i=1; i<=4; i++){
                String t = players["user$i"]?["type"] ?? "N";
                if(t != "N" && t != "D" && t != "BD") survivorCount++;
              }
              int myFixedRank = survivorCount;

              WriteBatch batch = fs.batch();
              String bankruptType = (playerType == 'B') ? "BD" : "D";

              batch.update(fs.collection("games").doc("users"), {
                "user$player.money": 0,
                "user$player.totalMoney": 0,
                "user$player.type": bankruptType,
                "user$player.rank": myFixedRank,
              });

              batch.update(fs.collection("games").doc("users"), {
                "user$owner.money": FieldValue.increment(remainingMoney),
                "user$owner.totalMoney": FieldValue.increment(remainingMoney),
              });

              final boardSnap = await fs.collection("games").doc("board").get();
              if (boardSnap.exists) {
                boardSnap.data()!.forEach((key, val) {
                  if (val is Map && val["owner"] == player) {
                    batch.update(fs.collection("games").doc("board"), {
                      "$key.owner": "N", "$key.level": 0, "$key.multiply": 1, "$key.isFestival": false
                    });
                  }
                });
              }
              await batch.commit();

              _triggerMoneyEffect("user$owner", remainingMoney);
              _triggerMoneyEffect("user$player", -remainingMoney);

              await _readPlayer(); await _readLocal();
              _nextTurn();
              return;
            }
          }

          await fs.collection("games").doc("users").update({
            "user$player.money": myMoney - finalToll,
            "user$player.totalMoney": myTotal - finalToll,
            "user$owner.money": ownerMoney + finalToll,
            "user$owner.totalMoney": ownerTotal + finalToll
          });

          if (isDoubleToll) {
            fs.collection("games").doc("users").update({"user$player.isDoubleToll" : false});
          }

          setState(() {
            players["user$player"]["money"] = myMoney - finalToll;
            players["user$player"]["totalMoney"] = myTotal - finalToll;
            players["user$owner"]["money"] = ownerMoney + finalToll;
            players["user$owner"]["totalMoney"] = ownerTotal + finalToll;
            if (isDoubleToll) {
              players["user$player"]["isDoubleToll"] = false;
            }
          });
          _triggerMoneyEffect("user$player", -finalToll);
          _triggerMoneyEffect("user$owner", finalToll);
        }

        if (boardList[tileKey]["level"] != 4) {
          if (playerType == 'B') {
            int takeoverCost = tollPrice * buildLevel * 2;
            int currentBotMoney = players["user$player"]["money"];

            if (currentBotMoney >= takeoverCost) {
              await fs.runTransaction((tx) async {
                tx.update(fs.collection("games").doc("users"), {
                  "user$player.money": FieldValue.increment(-takeoverCost),
                });
                tx.update(fs.collection("games").doc("users"), {
                  "user$owner.money": FieldValue.increment(takeoverCost),
                });
                tx.update(fs.collection("games").doc("board"), {
                  "b$changePosition.owner": player,
                });
              });
              _triggerMoneyEffect("user$player", -takeoverCost);
              _triggerMoneyEffect("user$owner", takeoverCost);
              await _readPlayer(); await _readLocal();
              await _botBuild(player, changePosition);
            }
          }
          else {
            final bool? takeoverSuccess = await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return TakeoverDialog(buildingId: changePosition, user: player);
              },
            );

            if (takeoverSuccess == true) {
              await _checkWinCondition(player);
              setState(() {
                if (boardList[tileKey] == null) boardList[tileKey] = {};
                boardList[tileKey]["owner"] = player;
              });
              await _readPlayer();
              await _readLocal();

              if (!mounted) return;

              int myLevel = players["user$player"]["level"] ?? 1;
              int currentBuildingLevel = (boardList[tileKey] != null) ? (boardList[tileKey]["level"] ?? 0) : 0;

              if (myLevel > currentBuildingLevel) {
                final constructionResult = await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return ConstructionDialog(user: player, buildingId: changePosition);
                  },
                );

                if (constructionResult != null) {
                  setState(() {
                    boardList[tileKey]["level"] = constructionResult["level"];
                    boardList[tileKey]["owner"] = constructionResult["user"];
                  });
                  await _readPlayer();
                  await _checkWinCondition(player);
                  await _readLocal();
                }
              }
            }
          }
        }
      }
      else {
        if (playerType == 'B') {
          await _botBuild(player, changePosition);
        } else {
          int myLevel = players["user$player"]["level"] ?? 1;
          int currentBuildingLevel = 0;

          if (myLevel > currentBuildingLevel) {
            final result = await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return ConstructionDialog(user: player, buildingId: changePosition);
                }
            );
            if (result != null && result is Map) {
              setState(() {
                if (boardList[tileKey] == null) boardList[tileKey] = {};
                boardList[tileKey]["level"] = result["level"];
                boardList[tileKey]["owner"] = result["user"];
              });
              await _readPlayer();
              await _checkWinCondition(player);
            }
          }
        }
      }
    }
    // 2. 국세청 (봇은 자동 납부)
    else if(changePosition == 26){
      if (playerType == 'B') {
        int myMoney = players["user$player"]["money"];
        int tax = (myMoney * 0.1).round();
        await fs.collection("games").doc("users").update({
          "user$player.money": FieldValue.increment(-tax),
          "user$player.totalMoney": FieldValue.increment(-tax),
        });
        _triggerMoneyEffect("user$player", -tax);
      } else {
        await showDialog(context: context, builder: (context)=> TaxDialog(user: player));
      }
      await _readPlayer();
    }
    // 3. 축제 (봇이면 무시)
    else if(changePosition == 14){
      // 💡 [수정] 봇은 축제 이벤트 패스
      if(playerType != 'B') {
        bool hasMyLand = false;
        boardList.forEach((key, val) {
          int owner = int.tryParse(val['owner'].toString()) ?? 0;
          if(val['type'] == 'land' && owner == player) hasMyLand = true;
        });
        if(hasMyLand) {
          _triggerHighlight(player, "festival");
          return;
        }
      }
    }
    // 4. 출발지 도착 (봇이면 무시 - 건설 X)
    else if(changePosition == 0){
      // 💡 [수정] 봇은 출발지 건설 이벤트 패스
      if (playerType != 'B') {
        bool hasUpgradableLand = false;
        boardList.forEach((key, val) {
          int owner = int.tryParse(val['owner'].toString()) ?? 0;
          int level = val['level'] ?? 0;
          if(val['type'] == 'land' && owner == player && level < 4) hasUpgradableLand = true;
        });
        if(hasUpgradableLand) {
          _triggerHighlight(player, "start");
          return;
        }
      }
    }
    // 5. 여행 (봇이면 무시)
    else if(changePosition == 21){
      // 💡 [수정] 봇은 여행 이벤트 패스
      if (playerType != 'B') {
        setState(() {
          players["user$player"]["isTraveling"] = true;
        });
        await fs.collection("games").doc("users").update({"user$player.isTraveling": true});
        forceNextTurn = true;
      }
    }
    // 6. 무인도 (여긴 봇도 걸려야 함)
    else if(changePosition == 7){
      forceNextTurn = true;
      await fs.collection("games").doc("users").update({
        "user$player.islandCount" : 3
      });
      await _readPlayer();
    }
    // 7. 찬스 카드 (봇이면 무시)
    else if ([3, 10, 17, 24].contains(changePosition)) {
      // 💡 [수정] 봇은 찬스카드 이벤트 패스 (퀴즈 X, 효과 X)
      if (playerType != 'B') {
        QuizQuestion? question = await QuizRepository.getRandomQuiz();
        bool isCorrect = false;
        int? selectedIndex;

        if (question != null && mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => QuizDialog(
              question: question,
              onQuizFinished: (index, correct) {
                selectedIndex = index;
                isCorrect = correct;
              },
            ),
          );

          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => QuizResultPopup(
                isCorrect: isCorrect,
                question: question,
                selectedIndex: selectedIndex ?? -1,
              ),
            );
          }
        }

        if (mounted) {
          final String? actionResult = await showDialog<String>(
            useSafeArea: false,
            context: context,
            barrierDismissible: false,
            builder: (context) => ChanceCardQuizAfter(
              quizEffect: isCorrect, storedCard: players["user$player"]["card"], userIndex: player,
            ),
          );

          // ... (찬스 카드 액션 처리 로직들) ...
          if (actionResult != null) {
            if (actionResult == "c_trip") {
              _movePlayerTo(21, player); return;
            } else if (actionResult == "c_festival") {
              // ...
              _triggerHighlight(player, "festival"); return;
            } else if (actionResult == "c_start") {
              _movePlayerTo(0, player); return;
            } else if (actionResult == "c_earthquake") {
              // 1. 공격 가능한 상대방 건물 찾기
              List<int> validTargets = [];

              boardList.forEach((key, val) {
                if (val is Map && val['type'] == 'land') {
                  int owner = int.tryParse(val['owner'].toString()) ?? 0;
                  int level = val['level'] ?? 0;

                  // 조건: 소유자가 있고(0 아님), 나(player)는 아니며, 랜드마크(4단계)가 아닌 땅
                  if (owner != 0 && owner != player && level < 4) {
                    validTargets.add(val['index']);
                  }
                }
              });

              // 2. 타겟이 하나도 없으면 알림 띄우고 종료
              if (validTargets.isEmpty) {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("지진 발생 실패"),
                    content: const Text("공격할 수 있는 상대방의 건물이 없습니다.\n(랜드마크는 공격할 수 없습니다)"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("확인"),
                      ),
                    ],
                  ),
                );
              }
              else {
                _triggerHighlight(player, "earthquake");
                return; // 하이라이트 켜고 선택 대기하므로 함수 종료
              }
            } else if (actionResult == "c_bonus") {
              await fs.collection("games").doc("users").update({
                "user$player.money" : players["user$player"]["money"] + 3000000,
                "user$player.totalMoney" : players["user$player"]["totalMoney"] + 3000000
              });
              _triggerMoneyEffect("user$player", 3000000);
            } else if (actionResult == "d_island") {
              _movePlayerTo(7, player);
            } else if (actionResult == "d_tax") {
              _movePlayerTo(26, player);
            } else if (actionResult == "d_rest") {
              await fs.collection("games").doc("users").update({"user$player.restCount": 1});
            } else if (actionResult == "d_priceUp") {
              await fs.collection("games").doc("users").update({"user$player.isDoubleToll": true});
            } else if (actionResult == "d_storm") {
              _triggerHighlight(player, "storm"); return;
            } else if (actionResult == "d_priceDown") {
              _triggerHighlight(player, "priceDown"); return;
            } else if (actionResult == "d_move") {
              Random ran = Random();
              int currentPos = players["user$player"]["position"];
              int randomPos = ran.nextInt(28);
              while(randomPos == currentPos) { randomPos = ran.nextInt(28); }

              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) _movePlayerTo(randomPos, player);
              });
              return;
            }
            await _readPlayer();
          }
        }
      }
    }

    _setPlayer();

    if (forceNextTurn || !isDouble) {
      // 더블이 아니거나 강제로 턴이 넘어가야 하는 경우 (여행, 무인도 등)
      _nextTurn();
    } else {
      // 더블인 경우
      doubleCount++;

      if (doubleCount >= 3) {
        // 더블 3번 연속 -> 무인도행
        setState(() {
          players["user$player"]["position"] = 7;
        });
        await fs.collection("games").doc("users").update({
          "user$player.position": 7,
          "user$player.islandCount": 3
        });
        _nextTurn();
      } else {
        // 💡 [수정] 더블이라서 한 번 더 굴려야 하는데, '봇(B)'이라면 자동으로 굴리기
        if (playerType == 'B') {
          print("🤖 봇 더블! 주사위 다시 굴립니다.");

          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;

            int d1 = Random().nextInt(6) + 1;
            int d2 = Random().nextInt(6) + 1;

            (diceAppKey.currentState as dynamic)?.rollDiceForBot(d1, d2);
          });
        }
      }
    }
  }

  Future<void> _botBuild(int player, int buildingId) async {
    String tileKey = "b$buildingId";
    int currentBuildingLevel = boardList[tileKey]["level"] ?? 0;
    int money = players["user$player"]["money"] ?? 0;
    int playerLapLevel = players["user$player"]["level"] ?? 1;

    int costPerLevel = 300000;

    int targetLevel = currentBuildingLevel;
    int totalCost = 0;

    int maxLimit;
    if (currentBuildingLevel == 3) {
      maxLimit = 4;
    } else {
      maxLimit = (playerLapLevel >= 3) ? 3 : playerLapLevel;
    }

    for (int l = currentBuildingLevel + 1; l <= maxLimit; l++) {
      if (money >= totalCost + costPerLevel) {
        totalCost += costPerLevel;
        targetLevel = l;
      } else {
        break;
      }
    }

    if (targetLevel > currentBuildingLevel) {
      await fs.runTransaction((tx) async {
        tx.update(fs.collection("games").doc("users"), {
          "user$player.money": FieldValue.increment(-totalCost),
        });
        tx.update(fs.collection("games").doc("board"), {
          "$tileKey.level": targetLevel,
          "$tileKey.owner": player,
        });
      });

      setState(() {
        boardList[tileKey]["level"] = targetLevel;
        boardList[tileKey]["owner"] = player;
      });
      _triggerMoneyEffect("user$player", -totalCost);

      await _readPlayer();
      await rankChange();
      setState(() {});

      await _checkWinCondition(player);
    }
  }

  void _nextTurn() {
    int survivors = 0;
    int lastSurvivorIndex = 0;

    for (int i = 1; i <= 4; i++) {
      String type = players["user$i"]?["type"] ?? "N";
      // 💡 [수정] D와 BD 둘 다 파산자
      if (type != "N" && type != "D" && type != "BD") {
        survivors++;
        lastSurvivorIndex = i;
      }
    }

    if (survivors <= 1) {
      _gameOver("bankruptcy", winnerIndex: lastSurvivorIndex);
      return;
    }

    setState(() {
      doubleCount = 0;
      int nextPlayer = currentTurn;
      int safetyLoop = 0;

      do {
        if (nextPlayer == 4) {
          nextPlayer = 1;
          totalTurn--;
          if (totalTurn == 0) {
            _gameOver("turn_limit");
            return;
          }
        } else {
          nextPlayer++;
        }
        safetyLoop++;

        String nextType = players["user$nextPlayer"]?["type"] ?? "N";
        // 💡 [수정] D 또는 BD인 경우 건너뜀
        if (nextType != "N" && nextType != "D" && nextType != "BD") {
          break;
        }
      } while (safetyLoop < 10);

      currentTurn = nextPlayer;
      _checkAndStartTurn();
    });
  }

  void _gameOver(String reason, {int? winnerIndex}) {
    int winIndex = winnerIndex ?? 0;
    context.go('/gameResult?victoryType=$reason&winnerName=$winIndex');
  }

  Future<void> rankChange() async {
    List<Map<String, dynamic>> tempUsers = [];
    for (int i = 1; i <= 4; i++) {
      // 💡 [수정] D와 BD 모두 랭킹 재산정 제외
      if (players["user$i"] != null && players["user$i"]["type"] != "N" &&
          players["user$i"]["type"] != "D" && players["user$i"]["type"] != "BD") {
        tempUsers.add({
          "key": "user$i",
          "totalMoney": players["user$i"]["totalMoney"] ?? 0,
          "money": players["user$i"]["money"] ?? 0,
        });
      }
    }

    tempUsers.sort((a, b) {
      int compare = b["totalMoney"].compareTo(a["totalMoney"]);
      if (compare == 0) {
        return b["money"].compareTo(a["money"]);
      }
      return compare;
    });

    for (int i = 0; i < tempUsers.length; i++) {
      String key = tempUsers[i]["key"];
      players[key]["rank"] = i + 1;
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

  Widget _buildPlayerInfoPanel({required Alignment alignment, required Map<String, dynamic> playerData, required Color color, required String name}) {
    String type = playerData['type'] ?? "N";
    if (type == "N") return const SizedBox();

    String displayName = (type == "B" || type == "BD") ? "bot" : name;
    if (type == "D" || type == "BD") {
      displayName += " (파산)";
    }

    bool isTop = alignment.y < 0;
    bool isLeft = alignment.x < 0;
    Color bgColor = color;

    String money = _formatMoney(playerData['money']);
    String totalMoney = _formatMoney(playerData['totalMoney']);

    int rank = playerData['rank'];

    String card = playerData['card'] ?? "";
    IconData? cardIcon;
    Color cardColor = Colors.grey;

    if (card == "shield") {
      cardIcon = Icons.shield;
      cardColor = Colors.blueAccent;
    } else if (card == "escape") {
      cardIcon = Icons.vpn_key;
      cardColor = Colors.orangeAccent;
    }

    // 💰 [추가] 통행료 2배 상태 확인
    bool isDoubleToll = playerData['isDoubleToll'] ?? false;

    String? effectText = _moneyEffects[name];

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
                top: isTop ? 40 : 0,
                left: isLeft ? 110 : 0,
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

              if (cardIcon != null)
                Positioned(
                  top: isTop ? 40 : 0,
                  left: isLeft ? 0 : 110,
                  child: Container(
                    width: 35, height: 35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                    ),
                    child: Icon(cardIcon, size: 20, color: Colors.white),
                  ),
                ),

              // 🔴 [추가] 통행료 2배 배지 (카드 아이콘 옆이나 위쪽에 배치)
              if (isDoubleToll)
                Positioned(
                  top: isTop ? 0 : 50, // 위치는 상황에 맞게 조정 (위쪽 패널이면 0, 아래쪽이면 50)
                  left: isLeft ? 120 : 10, // 좌측 패널이면 120, 우측이면 10 (카드와 반대편)
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                    ),
                    child: const Text(
                      "X2",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ),

              if (effectText != null)
                Positioned(
                  top: isTop ? -20 : -30,
                  left: isLeft ? 20 : 0,
                  right: isLeft ? 0 : 20,
                  child: Center(
                    child: Text(
                      effectText,
                      style: TextStyle(
                        color: effectText.startsWith("-") ? Colors.redAccent : Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(offset: Offset(-1, -1), color: Colors.black),
                          Shadow(offset: Offset(1, -1), color: Colors.black),
                          Shadow(offset: Offset(1, 1), color: Colors.black),
                          Shadow(offset: Offset(-1, 1), color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _showEventDialog() {
    String eventText = "";
    if(eventNow == "trip") eventText = "user${currentTurn}님 여행갈 땅을 선택해주세요!";
    else if(eventNow == "festival") eventText = "user${currentTurn}님 축제가 열릴 땅을 선택해주세요!";
    else if(eventNow == "start") eventText = "user${currentTurn}님 건설할 땅을 선택해주세요!";
    else if(eventNow == "storm") eventText = "user${currentTurn}님 태풍 피해를 입을 내 땅을 선택하세요.";
    else if(eventNow == "earthquake") eventText = "user${currentTurn}님 지진을 일으킬 상대 땅을 선택하세요!";
    else if(eventNow == "priceDown") eventText = "user${currentTurn}님 통행료를 할인할 내 땅을 선택하세요!";

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

    // 특수 칸 구분 로직
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

    Widget content;
    if(isSpecial) {
      content = _buildSpecialContent(label, icon!, index == 0, index);
    } else {
      content = _buildLandContent(barColor, tileName, tollPrice, index);
    }

    bool shouldGlow = false;
    int owner = 0;
    int level = 0;

    if(boardList["b$index"] != null) {
      owner = int.tryParse(boardList["b$index"]["owner"].toString()) ?? 0;
      level = boardList["b$index"]["level"] ?? 0;
    }

    if (_highlightOwner == -1) {
      if (eventNow == "trip") {
        if(index != 21) shouldGlow = true;
      }
      else if (eventNow == "earthquake") {
        if (owner != 0 && owner != _eventPlayer && level < 4) {
          shouldGlow = true;
        }
      }
    } else if (_highlightOwner != null && _highlightOwner == owner) {
      if (eventNow == "start") {
        if (level < 4) shouldGlow = true;
      } else {
        shouldGlow = true;
      }
    }

    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: GestureDetector(
        onTap: () async{
          if (shouldGlow) {
            _stopHighlight(index, eventNow);
          }
          else {
            if (!isSpecial && boardList["b$index"] != null && boardList["b$index"]["type"] == "land") {
              final result = await showDialog(context: context, builder: (context) {
                return DetailPopup(boardNum: index,onNext: (){},);
              });
              if(result != null){
                showDialog(context: context, builder: (context)=>BoardDetail(boardNum: index,data: result));
              }

              print("땅 상세정보 클릭: $index, $tileName");

            }
          }
        },
        child: Container(
          width: size, height: size, padding: const EdgeInsets.all(1.5),
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              double glowValue = _glowAnimation.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(6.0),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3, offset: const Offset(1, 2))],
                      border: Border.all(color: Colors.grey.shade400, width: 0.5),
                    ),
                    child: content,
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
        ),
      ),
    );
  }

  Widget _buildLandContent(Color color, String name, int price, int index) {
    var tileData = boardList["b$index"] ?? {};
    bool isFestival = itsFestival == index;
    double multiply = (tileData["multiply"] as num? ?? 0).toDouble();
    int buildLevel = tileData["level"] ?? 0;

    int levelvalue = 1;
    if (buildLevel == 0) {
      levelvalue = 0;
    } else {
      switch (buildLevel) {
        case 1: levelvalue = 2; break;
        case 2: levelvalue = 6; break;
        case 3: levelvalue = 14; break;
        case 4: levelvalue = 30; break;
      }
    }

    if (isFestival && multiply == 1) multiply *= 2;

    int tollPrice = (price * multiply * levelvalue).round();

    int level = tileData["level"] ?? 0;
    int owner = int.tryParse(tileData["owner"].toString()) ?? 0;

    final List<Color> ownerColors = [Colors.transparent, Colors.red, Colors.blue, Colors.green, Colors.purple];
    Color badgeColor = (owner >= 1 && owner <= 4) ? ownerColors[owner] : Colors.transparent;

    return ClipRRect(
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
                          // 💡 [수정] 콤마 함수 적용
                            Text(_formatMoney(tollPrice), style: TextStyle(fontSize: 6, color: Colors.grey[600])),
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
                  child: level != 4 ? Text("$level", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))
                      : Icon(Icons.star, size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
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

  Widget _buildAnimatedPlayer(int playerIndex, double boardSize, double tileSize) {
    String userKey = "user${playerIndex + 1}";
    String type = players[userKey]?["type"] ?? "N";

    // 파산하거나 게임에 없는 유저는 표시하지 않음
    if (type == "N" || type == "D" || type == "BD") return const SizedBox();

    int position = players[userKey]?["position"] ?? 0;

    // 1. 타일의 좌상단 좌표 가져오기
    Map<String, double> pos = _getTilePosition(position, boardSize, tileSize);
    double tileX = pos['left']!;
    double tileY = pos['top']!;

    // 2. 말판 크기 설정
    double tokenSize = 24.0;
    // overlapStep 변수는 이제 필요 없습니다. (옆으로 펼치지 않으므로)

    // 3. [핵심 수정] 타일의 '완전 정중앙' 좌표 계산
    // 타일의 중앙에서 말판 크기의 절반만큼 빼주면 말판의 중앙이 타일의 중앙과 일치합니다.
    // playerIndex를 좌표 계산에 더하지 않으므로 모든 말이 정확히 같은 위치에 겹칩니다.
    double centerOffset = (tileSize - tokenSize) / 2;
    double finalX = tileX + centerOffset;
    double finalY = tileY + centerOffset;

    // 색상 설정
    final List<Color> userColors = [Colors.red, Colors.blue, Colors.green, Colors.purple];

    // 내 차례인지 확인
    bool isMyTurn = (playerIndex + 1) == currentTurn;

    // 스타일 설정 (내 차례일 때만 불투명 + 테두리 강조)
    // 겹쳐 있기 때문에 투명도 조절이 중요합니다.
    double opacity = isMyTurn ? 1.0 : 0.3; // 내 차례가 아니면 좀 더 투명하게(0.3) 해서 겹친 느낌 강조
    double borderWidth = isMyTurn ? 3.0 : 1.0; // 내 차례가 아니면 테두리 얇게
    Color borderColor = Colors.white.withOpacity(isMyTurn ? 1.0 : 0.6);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      top: finalY,
      left: finalX,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: tokenSize,
        height: tokenSize,
        decoration: BoxDecoration(
            color: userColors[playerIndex].withOpacity(opacity),
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                // 내 차례일 때만 그림자를 진하게 줘서 맨 위에 떠있는 느낌을 줍니다.
                  color: Colors.black.withOpacity(isMyTurn ? 0.6 : 0.1),
                  blurRadius: isMyTurn ? 5 : 1,
                  offset: const Offset(1,1)
              )
            ]
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
                      child: _highlightOwner == null
                          ? DiceApp(
                        key: diceAppKey,
                        turn: currentTurn,
                        totalTurn: totalTurn,
                        // 💡 [추가] 현재 플레이어의 타입을 확인해서 전달
                        isBot: (players["user$currentTurn"]?["type"] == "B"),
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
            // 💡 [쿼터뷰 효과 적용 끝]
            _buildPlayerInfoPanel(alignment: Alignment.bottomRight, playerData: players['user1'], color: Colors.red, name : "user1"),
            _buildPlayerInfoPanel(alignment: Alignment.topLeft, playerData: players['user2'], color : Colors.blue, name : "user2"),
            _buildPlayerInfoPanel(alignment: Alignment.bottomLeft, playerData: players['user3'], color: Colors.green, name : "user3"),
            _buildPlayerInfoPanel(alignment: Alignment.topRight, playerData: players['user4'], color : Colors.purple, name : "user4"),
          ],
        ),
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