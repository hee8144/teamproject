import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dice.dart'; // diceAppKey, DiceApp import
import '../Popup/construction.dart';
import '../Popup/TaxDialog.dart';
import '../Popup/Bankruptcy.dart';
import '../Popup/Takeover.dart';
import '../Popup/Island.dart';
import '../Popup/BoardDetail.dart';
import '../Popup/Detail.dart';
import '../quiz/quiz_repository.dart';
import '../quiz/quiz_question.dart';
import '../quiz/quiz_dialog.dart';
import '../quiz/quiz_result_popup.dart';
import '../quiz/chance_card_quiz_after.dart';

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
  int itsFestival = 0;

  int currentTurn = 1;
  int totalTurn = 30;
  int doubleCount = 0;

  // 💡 방금 굴린 주사위가 더블이었는지 저장 (턴 처리용)
  bool _lastIsDouble = false;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  int? _highlightOwner;

  // 💡 돈 변화 이펙트
  Map<String, String?> _moneyEffects = {};

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

  // 💡 돈 변화 이펙트 표시 함수
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

  // 💡 주사위 굴리기
  Future<void> _onDiceRoll(int val1, int val2) async {
    bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
    int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

    if (isTraveling) {
      setState(() {
        players["user$currentTurn"]["isTraveling"] = false;
      });
      await fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
      _triggerHighlight(currentTurn, "trip");
      return;
    }

    if (islandCount > 0) {
      bool isDouble = (val1 == val2);

      if (isDouble) {
        await fs.collection("games").doc("users").update({
          "user$currentTurn.islandCount": 0
        });
        setState(() {
          players["user$currentTurn"]["islandCount"] = 0;
        });
      } else {
        int newCount = islandCount - 1;
        await fs.collection("games").doc("users").update({
          "user$currentTurn.islandCount": newCount
        });
        setState(() {
          players["user$currentTurn"]["islandCount"] = newCount;
        });
        _nextTurn();
        return;
      }
    }

    int total = val1 + val2;
    bool isDouble = (val1 == val2);
    movePlayer(7, currentTurn, isDouble);
  }

  // 💡 턴 시작 체크 (봇 자동화 포함)
  Future<void> _checkAndStartTurn() async {
    String type = players["user$currentTurn"]?["type"] ?? "N";

    // 1. 없는 유저나 파산(D) 유저 건너뛰기
    if (type == "N" || type == "D") {
      _nextTurn();
      return;
    }

    // 💡 [추가] 턴 시작 시, 내 땅 중에 할인(0.5배)된 땅이 있다면 정상(1배)으로 복구
    // (지난 턴에 d_priceDown으로 0.5배가 된 것을 이번 턴에 원상복구)
    bool needUpdate = false;
    WriteBatch batch = fs.batch();

    boardList.forEach((key, val) {
      if (val is Map && val['type'] == 'land') {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        double multiply = (val['multiply'] as num? ?? 1.0).toDouble();

        // 내 땅이고 배수가 1보다 작으면(0.5 등) 초기화
        if (owner == currentTurn && multiply < 1.0) {
          batch.update(fs.collection("games").doc("board"), {
            "$key.multiply": 1
          });
          val['multiply'] = 1; // 로컬 반영을 위해
          needUpdate = true;
        }
      }
    });

    if (needUpdate) {
      await batch.commit();
      setState(() {}); // 로컬 화면 갱신
    }

    int restCount = players["user$currentTurn"]["restCount"] ?? 0;

    if (restCount > 0) {
      // 휴식 카운트 감소
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
            builder: (BuildContext dialogContext) { // 💡 builder의 context를 따로 이름 지어줍니다 (헷갈림 방지)

              // 👇 2초 뒤에 자동으로 닫는 로직 추가
              Future.delayed(const Duration(seconds: 2), () {
                // 2초 뒤에 다이얼로그가 여전히 떠있다면 닫기 (오류 방지용 mounted 체크)
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
                      const Text( // 💡 const 추가 (성능 최적화)
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

    // 💡 봇 로직
    if (type == "B") {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        int d1 = Random().nextInt(6) + 1;
        int d2 = Random().nextInt(6) + 1;
        (diceAppKey.currentState as dynamic)?.rollDiceForBot(d1, d2);
      });
      return;
    }

    // --- 사람 플레이어 ---
    int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

    if (islandCount > 0) {
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
      }
    }

    bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
    if (isTraveling) {
      setState(() {
        players["user$currentTurn"]["isTraveling"] = false;
      });
      await fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
      _triggerHighlight(currentTurn, "trip");
    }
  }

  void _triggerHighlight(int player, String event) {
    _eventPlayer = player;
    // 전체 맵 하이라이트 이벤트
    if(event == "trip" || event == "earthquake"){
      setState(() {
        _highlightOwner = -1;
        eventNow = event;
      });
    } else {
      // 내 땅만 하이라이트 (priceDown 포함)
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
      }
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
      _movePlayerTo(index, _eventPlayer);

    } else if (event == "earthquake") {
      await _executeEarthquake(index);
      _handleTurnEnd();

    } else if (event == "storm") {
      await _executeEarthquake(index);
      _handleTurnEnd();

    }
    // 💡 [추가] 통행료 할인 이벤트 처리
    else if (event == "priceDown") {
      // 해당 땅의 배수를 0.5로 변경 (다음 턴까지)
      await fs.collection("games").doc("board").update({
        "b$index.multiply": 0.5
      });

      // 로컬 반영
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

  void movePlayer(int steps, int player, bool isDouble) async {
    _lastIsDouble = isDouble;
    String playerType = players["user$player"]["type"] ?? "P";

    int currentPos = players["user$player"]["position"];
    int nextPos = currentPos + steps;
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
      int owner = int.tryParse(boardList[tileKey]["owner"].toString()) ?? 0;
      int buildLevel = boardList[tileKey]["level"] ?? 0;
      int tollPrice = boardList[tileKey]["tollPrice"] ?? 0;

      // 1. 내 땅일 때 (증축)
      if(owner == player) {
        if (playerType == 'B') {
          await _botBuild(player, changePosition);
        } else {
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
          }
        }
      }
      // 2. 상대방 땅일 때 (통행료 지불 + 인수)
      else if(owner != 0 && owner != player) {
        if(players["user$player"]["card"] == "sheild"){
          // 쉴드 카드 있을때 사용할지 물어보는 함수 넣을 자리
        }   
        // 통행료 계산
        int basePrice = boardList[tileKey]["tollPrice"] ?? 0;
        double multiply = (boardList[tileKey]["multiply"] as num? ?? 0).toDouble();
        if(itsFestival == changePosition && multiply == 1) multiply *= 2;
        int levelMulti = 1;

        // 💡 [수정] 레벨 0이면 통행료 0, 랜드마크(4)는 x30
        if (buildLevel == 0) {
          levelMulti = 0;
        } else {
          switch (buildLevel) {
            case 1: levelMulti = 2; break;
            case 2: levelMulti = 6; break;
            case 3: levelMulti = 14; break;
            case 4: levelMulti = 30; break; // 40 -> 30으로 수정
          }
        }

        int finalToll = (basePrice * multiply * levelMulti).round();

        bool isDoubleToll = players["user$player"]["isDoubleToll"] ?? false;
        if (isDoubleToll) {
          finalToll *= 2;
        }

        int myMoney = players["user$player"]["money"];
        int myTotal = players["user$player"]["totalMoney"];
        int ownerMoney = players["user$owner"]["money"];
        int ownerTotal = players["user$owner"]["totalMoney"];

        if(myMoney - finalToll < 0){
          if (playerType == 'B') {
            await fs.collection("games").doc("users").update({
              "user$player.type": "D"
            });
            final boardSnap = await fs.collection("games").doc("board").get();
            if (boardSnap.exists) {
              final batch = fs.batch();
              boardSnap.data()!.forEach((key, val) {
                if (val is Map && val["owner"] == player) {
                  batch.update(fs.collection("games").doc("board"), {
                    "$key.owner": "N", "$key.level": 0, "$key.multiply": 1, "$key.isFestival": false
                  });
                }
              });
              await batch.commit();
            }
            await _readPlayer(); await _readLocal(); _nextTurn(); return;
          } else {
            final result = await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return BankruptDialog(lackMoney: finalToll - myMoney, reason: "toll", user: player);
                }
            );
            if (result != null && result is Map && result["result"] == "BANKRUPT") {
              await _readPlayer(); await _readLocal(); _nextTurn(); return;
            } else if (result == "SURVIVED") {
              await _readPlayer();
              myMoney = players["user$player"]["money"]; myTotal = players["user$player"]["totalMoney"];
            }
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
          } else {
            final bool? takeoverSuccess = await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return TakeoverDialog(buildingId: changePosition, user: player);
              },
            );
            if (takeoverSuccess == true) {
              await _readLocal();
              if (!mounted) return;
              final constructionResult = await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return ConstructionDialog(user: player, buildingId: changePosition);
                },
              );
              if (constructionResult != null) {
                setState(() {
                  if (boardList[tileKey] == null) boardList[tileKey] = {};
                  boardList[tileKey]["level"] = constructionResult["level"];
                  boardList[tileKey]["owner"] = constructionResult["user"];
                });
                await _readLocal();
              }
            }
          }
        }
      }
      else {
        if (playerType == 'B') {
          await _botBuild(player, changePosition);
        } else {
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
          }
        }
      }
    }
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
    }
    else if(changePosition == 14){
      bool hasMyLand = false;
      boardList.forEach((key, val) {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        if(val['type'] == 'land' && owner == player) hasMyLand = true;
      });
      if(hasMyLand) {
        if (playerType == 'B') {
          List<String> myLandKeys = [];
          boardList.forEach((key, val) {
            if(val['type'] == 'land' && val['owner'] == player) myLandKeys.add(key);
          });
          if(myLandKeys.isNotEmpty) {
            String targetKey = myLandKeys[Random().nextInt(myLandKeys.length)];
            if(itsFestival != 0){
              await fs.collection("games").doc("board").update({"b$itsFestival.isFestival" : false});
            }
            await fs.collection("games").doc("board").update({"$targetKey.isFestival" : true});
            int targetIndex = int.parse(targetKey.substring(1));
            setState(() { itsFestival = targetIndex; });
            await _readLocal();
            _handleTurnEnd();
            return;
          }
        } else {
          _triggerHighlight(player, "festival");
          return;
        }
      }
    }
    else if(changePosition == 0){
      bool hasUpgradableLand = false;
      boardList.forEach((key, val) {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        int level = val['level'] ?? 0;
        if(val['type'] == 'land' && owner == player && level < 4) hasUpgradableLand = true;
      });
      if(hasUpgradableLand) {
        if(playerType == 'B') {
          List<int> targets = [];
          boardList.forEach((key, val) {
            if(val['type'] == 'land' && val['owner'] == player && val['level'] < 4) {
              targets.add(val['index']);
            }
          });
          if(targets.isNotEmpty) {
            int targetIdx = targets[Random().nextInt(targets.length)];
            await _botBuild(player, targetIdx);
            _handleTurnEnd();
            return;
          }
        } else {
          _triggerHighlight(player, "start");
          return;
        }
      }
    }
    else if(changePosition == 21){
      setState(() {
        players["user$player"]["isTraveling"] = true;
      });
      await fs.collection("games").doc("users").update({"user$player.isTraveling": true});
      forceNextTurn = true;
    }
    else if(changePosition == 7){
      forceNextTurn = true;
      await fs.collection("games").doc("users").update({
        "user$player.islandCount" : 3
      });
      await _readPlayer();
    }
    else if ([3, 10, 17, 24].contains(changePosition)) {
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
          context: context,
          barrierDismissible: false,
          builder: (context) => ChanceCardQuizAfter(
            quizEffect: isCorrect,
          ),
        );

        if (actionResult != null) {
          print("찬스카드 액션 실행: $actionResult");

          if (actionResult == "c_trip") {
            _movePlayerTo(21, player);
            return;
          }
          else if (actionResult == "c_festival") {
            bool hasMyLand = false;
            boardList.forEach((key, val) {
              int owner = int.tryParse(val['owner'].toString()) ?? 0;
              if (val['type'] == 'land' && owner == player) {
                hasMyLand = true;
              }
            });

            if (!hasMyLand) {
              await showDialog(
                context: context,
                builder: (context) => const AlertDialog(content: Text("축제를 열 수 있는 내 땅이 없습니다.")),
              );
              _handleTurnEnd();
              return;
            }
            _triggerHighlight(player, "festival");
            return;
          }
          else if (actionResult == "c_start") {
            _movePlayerTo(0, player);
            return;
          }
          else if (actionResult == "c_earthquake") {
            List<int> validTargets = [];
            boardList.forEach((key, val) {
              if (val is Map && val['type'] == 'land') {
                int owner = int.tryParse(val['owner'].toString()) ?? 0;
                int level = val['level'] ?? 0;
                if (owner != 0 && owner != player && level < 4) {
                  validTargets.add(val['index']);
                }
              }
            });

            if (validTargets.isEmpty) {
              await showDialog(
                context: context,
                builder: (context) => const AlertDialog(content: Text("공격할 수 있는 상대 땅이 없습니다.")),
              );
              _handleTurnEnd();
              return;
            }

            if (playerType == 'B') {
              int targetIndex = validTargets[Random().nextInt(validTargets.length)];
              await _executeEarthquake(targetIndex);
              _handleTurnEnd();
              return;
            } else {
              _triggerHighlight(player, "earthquake");
              return;
            }
          }
          else if(actionResult == "c_bonus"){
            await fs.collection("games").doc("users").update({
              "user$player.money" : players["user$player"]["money"] + 3000000,
              "user$player.totalMoney" : players["user$player"]["totalMoney"] + 3000000
            });
            _triggerMoneyEffect("user$player", 3000000);
          }
          else if(actionResult == "d_island"){
            _movePlayerTo(7, player);
          }
          else if(actionResult == "d_tax"){
            _movePlayerTo(26, player);
          }
          else if(actionResult == "d_rest"){
            await fs.collection("games").doc("users").update({
              "user$player.restCount": 1
            });
          }
          else if(actionResult == "d_priceUp"){
            await fs.collection("games").doc("users").update({
              "user$player.isDoubleToll": true
            });
          }
          else if(actionResult == "d_storm"){
            List<int> myLands = [];
            boardList.forEach((key, val) {
              if (val['type'] == 'land') {
                int owner = int.tryParse(val['owner'].toString()) ?? 0;
                if (owner == player) {
                  myLands.add(val['index']);
                }
              }
            });

            if (myLands.isEmpty) {
              await showDialog(
                context: context,
                builder: (context) => const AlertDialog(content: Text("태풍이 지나갔지만 피해를 입을 건물이 없습니다.")),
              );
              _handleTurnEnd();
              return;
            }

            if (playerType == 'B') {
              int targetIndex = myLands[Random().nextInt(myLands.length)];
              await _executeEarthquake(targetIndex);
              _handleTurnEnd();
              return;
            } else {
              _triggerHighlight(player, "storm");
              return;
            }
          }
          // 💡 [추가] 통행료 할인(반값) 이벤트 로직
          else if(actionResult == "d_priceDown"){
            // 1. 내가 가진 땅 목록 찾기
            List<int> myLands = [];
            boardList.forEach((key, val) {
              if (val['type'] == 'land') {
                int owner = int.tryParse(val['owner'].toString()) ?? 0;
                if (owner == player) {
                  myLands.add(val['index']);
                }
              }
            });

            // 2. 내 땅이 없으면 패스
            if (myLands.isEmpty) {
              await showDialog(
                context: context,
                builder: (context) => const AlertDialog(content: Text("할인할 내 땅이 없습니다.")),
              );
              _handleTurnEnd();
              return;
            }

            // 3. 봇 vs 사람
            if (playerType == 'B') {
              // 봇: 랜덤 선택 후 배수 0.5로 설정
              int targetIndex = myLands[Random().nextInt(myLands.length)];
              await fs.collection("games").doc("board").update({"b$targetIndex.multiply" : 0.5});
              _handleTurnEnd();
              return;
            } else {
              // 사람: 하이라이트 켜서 선택 유도 (내 땅만 빛남)
              _triggerHighlight(player, "priceDown");
              return;
            }
          }
        }
        else if(actionResult == "d_move"){
          Random ran = Random();
          int random = ran.nextInt(28);
          while(random == players["user$player"]["position"]) {
            random = ran.nextInt(28);
          }
          _movePlayerTo(random, player);
          return;
        }
        await _readPlayer();
      }
    }


    _setPlayer();

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
    }
  }

  void _nextTurn() {
    int survivors = 0;
    int lastSurvivorIndex = 0;

    for (int i = 1; i <= 4; i++) {
      String type = players["user$i"]?["type"] ?? "N";
      if (type != "N" && type != "D") {
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
        if (nextType != "N" && nextType != "D") {
          break;
        }
      } while (safetyLoop < 10);

      currentTurn = nextPlayer;
      _checkAndStartTurn();
    });
  }

  void _gameOver(String reason, {int? winnerIndex}) {
    print("게임 종료! 사유: $reason, 승자: $winnerIndex");
  }

  // ... (rankChange, _readPlayer, _readLocal, _insertLocal 등 하단 함수들 기존 동일) ...
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

  Widget _buildPlayerInfoPanel({required Alignment alignment, required Map<String, dynamic> playerData, required Color color, required String name}) {
    String type = playerData['type'] ?? "N";
    if (type == "N") return const SizedBox();

    String displayName = (type == "B") ? "bot" : name;

    if (type == "D") {
      displayName += " (파산)";
    }

    bool isTop = alignment.y < 0;
    bool isLeft = alignment.x < 0;
    Color bgColor = color;
    String money = "${playerData['money']}";
    String totalMoney = "${playerData['totalMoney']}";
    int rank = playerData['rank'];

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
    if(eventNow == "trip") eventText = "여행갈 땅을 선택해주세요!";
    else if(eventNow == "festival") eventText = "축제가 열릴 땅을 선택해주세요!";
    else if(eventNow == "start") eventText = "건설할 땅을 선택해주세요!";
    else if(eventNow == "storm") eventText = "태풍 피해를 입을 내 땅을 선택하세요.";
    else if(eventNow == "earthquake") eventText = "지진을 일으킬 상대 땅을 선택하세요!";
    // 💡 [추가] 통행료 할인 이벤트 문구
    else if(eventNow == "priceDown") eventText = "통행료를 할인할 내 땅을 선택하세요!";

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
      // 💡 [추가] 지진: 상대방 땅이고 랜드마크가 아니면 빛남
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
          // 1. 이벤트 하이라이트 상태일 때 (땅 선택)
          if (shouldGlow) {
            _stopHighlight(index, eventNow);
          }
          // 2. 평상시 클릭 (상세보기)
          else {
            // 💡 [수정] 특수 칸이 아니고 일반 땅(land)일 때만 실행
            if (!isSpecial && boardList["b$index"] != null && boardList["b$index"]["type"] == "land") {
              // TODO: 여기에 상세정보 보여주는 함수 호출
              // showDetailInfo(index);
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
    // 💡 [수정] 레벨 0일 경우 levelValue 0, 랜드마크(4)일 경우 30배
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

    final List<Color> ownerColors = [Colors.transparent, Colors.red, Colors.blue, Colors.green, Colors.yellow];
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
                            Text("$tollPrice", style: TextStyle(fontSize: 7, color: Colors.grey[600])),
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
    // 💡 파산했거나 없는 플레이어는 표시 안 함
    if (type == "N" || type == "D") return const SizedBox();

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
            _buildPlayerInfoPanel(alignment: Alignment.bottomRight, playerData: players['user1'], color: Colors.red, name : "user1"),
            _buildPlayerInfoPanel(alignment: Alignment.topLeft, playerData: players['user2'], color : Colors.blue, name : "user2"),
            _buildPlayerInfoPanel(alignment: Alignment.bottomLeft, playerData: players['user3'], color: Colors.green, name : "user3"),
            _buildPlayerInfoPanel(alignment: Alignment.topRight, playerData: players['user4'], color : Colors.yellow, name : "user4"),
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