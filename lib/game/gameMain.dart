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

  // 💡 주사위 위젯 제어용 키 (dice.dart에 정의된 것을 사용하거나 여기서 정의)
  // 만약 dice.dart에 전역 변수로 정의하지 않았다면 아래 줄 주석 해제 후 사용
  // final GlobalKey diceAppKey = GlobalKey();

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

  // 💡 주사위 굴리기 (무인도 탈출 시도 로직 포함)
  Future<void> _onDiceRoll(int val1, int val2) async {
    bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
    int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

    // 1. 여행 중일 때
    if (isTraveling) {
      setState(() {
        players["user$currentTurn"]["isTraveling"] = false;
      });
      await fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
      _triggerHighlight(currentTurn, "trip");
      return;
    }

    // 2. 무인도 탈출 시도 (주사위)
    if (islandCount > 0) {
      bool isDouble = (val1 == val2);

      if (isDouble) {
        // 더블! 탈출 성공 -> 이동
        await fs.collection("games").doc("users").update({
          "user$currentTurn.islandCount": 0
        });
        setState(() {
          players["user$currentTurn"]["islandCount"] = 0;
        });
        // 탈출했으니 아래 movePlayer 실행됨
      } else {
        // 탈출 실패 -> 카운트 감소, 턴 종료
        int newCount = islandCount - 1;
        await fs.collection("games").doc("users").update({
          "user$currentTurn.islandCount": newCount
        });
        setState(() {
          players["user$currentTurn"]["islandCount"] = newCount;
        });

        // 이동하지 않고 턴 넘기기
        _nextTurn();
        return;
      }
    }

    // 3. 일반 이동
    int total = val1 + val2;
    bool isDouble = (val1 == val2);
    movePlayer(total, currentTurn, isDouble);
  }

  // 💡 턴 시작 체크 (봇 자동화 포함)
  Future<void> _checkAndStartTurn() async {
    String type = players["user$currentTurn"]?["type"] ?? "N";

    // 1. 없는 유저나 파산(D) 유저 건너뛰기
    if (type == "N" || type == "D") {
      _nextTurn();
      return;
    }

    // 💡 2. 봇(B)일 경우 자동 주사위 굴리기
    if (type == "B") {
      // 1.5초 딜레이 (봇이 생각하는 척)
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        // 랜덤 주사위값 생성
        int d1 = Random().nextInt(6) + 1;
        int d2 = Random().nextInt(6) + 1;

        // 💡 DiceApp의 애니메이션 실행 (dice.dart에 diceAppKey가 정의되어 있어야 함)
        // 만약 에러나면 dynamic으로 캐스팅하거나 state를 public으로 변경 필요
        (diceAppKey.currentState as dynamic)?.rollDiceForBot(d1, d2);
      });
      return; // 봇은 아래 사람용 UI 로직 건너뜀
    }

    // --- 👇 사람(Human) 플레이어 로직 ---

    // 3. 사람일 때만 무인도 다이얼로그 표시
    int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

    if (islandCount > 0) {
      final bool? paidToEscape = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => IslandDialog(user: currentTurn)
      );

      if (paidToEscape == true) {
        // 돈 내고 탈출 성공
        await fs.collection("games").doc("users").update({
          "user$currentTurn.islandCount": 0
        });
        setState(() {
          players["user$currentTurn"]["islandCount"] = 0;
        });
      }
    }

    // 4. 여행 중이면 맵 하이라이트
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
    if(event == "trip"){
      setState(() {
        _highlightOwner = -1; // 전체 맵
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
    }
  }

  // 💡 이벤트 후 더블 여부에 따라 턴 넘기기 or 유지
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
      // 더블이면 턴 안 넘김 (한 번 더)
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

  // 💡 핵심 이동 로직 (봇 자동화 포함)
  void movePlayer(int steps, int player, bool isDouble) async {
    _lastIsDouble = isDouble;
    String playerType = players["user$player"]["type"] ?? "P";

    int currentPos = players["user$player"]["position"];
    int nextPos = currentPos + steps;
    int changePosition = nextPos > 27 ? nextPos % 28 : nextPos;

    // 월급 지급
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
          // 🤖 봇: 자동 증축
          await _botBuild(player, changePosition);
        } else {
          // 🧑 사람: 건설 다이얼로그
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
        // 통행료 계산
        int basePrice = boardList[tileKey]["tollPrice"] ?? 0;
        double multiply = (boardList[tileKey]["multiply"] as num? ?? 0).toDouble();
        if(itsFestival == changePosition && multiply == 1) multiply *= 2;
        int levelMulti = 1;
        switch (buildLevel) {
          case 1: levelMulti = 2; break;
          case 2: levelMulti = 6; break;
          case 3: levelMulti = 14; break;
          case 4: levelMulti = 40; break;
        }
        int finalToll = (basePrice * multiply * levelMulti).round();

        int myMoney = players["user$player"]["money"];
        int myTotal = players["user$player"]["totalMoney"];
        int ownerMoney = players["user$owner"]["money"];
        int ownerTotal = players["user$owner"]["totalMoney"];

        // 파산 체크
        if(myMoney - finalToll < 0){
          if (playerType == 'B') {
            // 🤖 봇 파산 처리
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
            // 🧑 사람 파산 다이얼로그
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

        // 통행료 지불
        await fs.collection("games").doc("users").update({
          "user$player.money": myMoney - finalToll,
          "user$player.totalMoney": myTotal - finalToll,
          "user$owner.money": ownerMoney + finalToll,
          "user$owner.totalMoney": ownerTotal + finalToll
        });
        setState(() {
          players["user$player"]["money"] = myMoney - finalToll;
          players["user$player"]["totalMoney"] = myTotal - finalToll;
          players["user$owner"]["money"] = ownerMoney + finalToll;
          players["user$owner"]["totalMoney"] = ownerTotal + finalToll;
        });
        _triggerMoneyEffect("user$player", -finalToll);
        _triggerMoneyEffect("user$owner", finalToll);

        // 인수 로직
        if (boardList[tileKey]["level"] != 4) {
          if (playerType == 'B') {
            // 🤖 봇 인수
            int takeoverCost = tollPrice * buildLevel * 2;
            int currentBotMoney = players["user$player"]["money"];

            if (currentBotMoney >= takeoverCost) {
              await fs.runTransaction((tx) async {
                // 봇 돈 차감
                tx.update(fs.collection("games").doc("users"), {
                  "user$player.money": FieldValue.increment(-takeoverCost),
                });
                // 원주인 돈 입금
                tx.update(fs.collection("games").doc("users"), {
                  "user$owner.money": FieldValue.increment(takeoverCost),
                });
                // 주인 변경
                tx.update(fs.collection("games").doc("board"), {
                  "b$changePosition.owner": player,
                });
              });
              _triggerMoneyEffect("user$player", -takeoverCost);
              _triggerMoneyEffect("user$owner", takeoverCost);

              await _readPlayer(); await _readLocal();

              // 인수 후 추가 건설
              await _botBuild(player, changePosition);
            }
          } else {
            // 🧑 사람 인수
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
      // 3. 빈 땅일 때 (건설)
      else {
        if (playerType == 'B') {
          // 🤖 봇 건설
          await _botBuild(player, changePosition);
        } else {
          // 🧑 사람 건설
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
    else if(changePosition == 26){ // 국세청
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
    else if(changePosition == 14){ // 축제
      bool hasMyLand = false;
      boardList.forEach((key, val) {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        if(val['type'] == 'land' && owner == player) hasMyLand = true;
      });
      if(hasMyLand) {
        if (playerType == 'B') {
          // 🤖 봇: 랜덤 축제 개최
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
    else if(changePosition == 0){ // 출발
      bool hasUpgradableLand = false;
      boardList.forEach((key, val) {
        int owner = int.tryParse(val['owner'].toString()) ?? 0;
        int level = val['level'] ?? 0;
        if(val['type'] == 'land' && owner == player && level < 4) hasUpgradableLand = true;
      });
      if(hasUpgradableLand) {
        if(playerType == 'B') {
          // 🤖 봇: 랜덤 증축
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
    else if(changePosition == 21){ // 여행
      setState(() {
        players["user$player"]["isTraveling"] = true;
      });
      await fs.collection("games").doc("users").update({"user$player.isTraveling": true});
      forceNextTurn = true;
    }
    else if(changePosition == 7){ // 무인도
      forceNextTurn = true;
      await fs.collection("games").doc("users").update({
        "user$player.islandCount" : 3
      });
      await _readPlayer();
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

  // 🤖 봇 건설 함수
  // 🤖 봇 전용 건설 함수 (플레이어 레벨에 따른 건설 제한 적용)
  Future<void> _botBuild(int player, int buildingId) async {
    String tileKey = "b$buildingId";
    int currentBuildingLevel = boardList[tileKey]["level"] ?? 0; // 현재 건물 레벨
    int money = players["user$player"]["money"] ?? 0; // 봇의 돈
    int playerLapLevel = players["user$player"]["level"] ?? 1; // 💡 플레이어의 바퀴 수 (레벨)

    // 건설 비용 (임시: 30만원 고정)
    int costPerLevel = 300000;

    int targetLevel = currentBuildingLevel;
    int totalCost = 0;

    // 💡 [수정됨] 건설 가능한 최대 레벨 제한 설정
    int maxLimit;

    if (currentBuildingLevel == 3) {
      // 이미 3단계(호텔)라면 -> 랜드마크(4) 건설 가능 (보통 랜드마크는 바퀴 수 제한 없음, 혹은 3바퀴 이상)
      maxLimit = 4;
    } else {
      // 0, 1, 2단계일 때 -> 플레이어의 바퀴 수(Level)까지만 건설 가능 (단, 최대 3단계까지)
      // 예: 1바퀴(Lv1) -> 1단계(별장)까지만
      //     2바퀴(Lv2) -> 2단계(빌딩)까지만
      //     3바퀴(Lv3) 이상 -> 3단계(호텔)까지
      maxLimit = (playerLapLevel >= 3) ? 3 : playerLapLevel;
    }

    // 목표 레벨까지 반복 계산
    for (int l = currentBuildingLevel + 1; l <= maxLimit; l++) {
      // 비용 체크
      if (money >= totalCost + costPerLevel) {
        totalCost += costPerLevel;
        targetLevel = l;
      } else {
        break; // 돈 부족하면 멈춤
      }
    }

    // 변경사항이 있을 때만 DB 업데이트
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

      // 로컬 화면 갱신 및 이펙트
      setState(() {
        boardList[tileKey]["level"] = targetLevel;
        boardList[tileKey]["owner"] = player;
      });
      _triggerMoneyEffect("user$player", -totalCost);

      await _readPlayer();
    }
  }

  void _nextTurn() {
    setState(() {
      doubleCount = 0;
      int nextPlayer = currentTurn;
      int safetyLoop = 0;

      do {
        if (nextPlayer == 4) {
          nextPlayer = 1;
          totalTurn--;
          if(totalTurn == 0) {
            // 게임 종료
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
      if(index != 21) {
        shouldGlow = true;
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
        onTap: () {
          if (shouldGlow) {
            _stopHighlight(index, eventNow);
          } else{
          //   상세정보 넣을자리 제미나이야 이부분 지우지마
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