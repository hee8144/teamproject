  import 'dart:async';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:go_router/go_router.dart';
  import 'package:flutter/material.dart';
  import 'dart:math';

  // ✅ 분리된 4개의 파일 (데이터, 규칙, UI)
  import 'heritage_repository.dart';
  import 'logic/game_rules.dart'; // 🔥 새로 추가된 규칙 파일
  import 'widgets/player_info_panel.dart';
  import 'widgets/game_board_tile.dart';
  import 'widgets/player_token.dart';

  import '../Popup/warning.dart';
  import 'dice.dart';
  import '../Popup/construction.dart';
  import '../Popup/TaxDialog.dart';
  import '../Popup/Bankruptcy.dart';
  import '../Popup/Takeover.dart';
  import '../Popup/Island.dart';
  import '../Popup/BoardDetail.dart';
  import '../Popup/Detail.dart';
  import '../Popup/CardUse.dart';
  import '../Popup/check.dart';
  import '../Popup/PlayerDetailPopup.dart';
  import '../quiz/quiz_repository.dart';
  import '../quiz/quiz_question.dart';
  import '../quiz/quiz_dialog.dart';
  import '../quiz/quiz_result_popup.dart';
  import '../quiz/chance_card_quiz_after.dart';
  import '../quiz/DiscountQuizManager.dart';
  import '../widgets/loading_screen.dart';
  import 'logic/game_log_manager.dart';

  class GameMain extends StatefulWidget {
    const GameMain({super.key});

    @override
    State<GameMain> createState() => _GameMainState();
  }

  class _GameMainState extends State<GameMain> with TickerProviderStateMixin {
    FirebaseFirestore fs = FirebaseFirestore.instance;
    final HeritageRepository _heritageRepo = HeritageRepository();
    final GameLogManager _logManager = GameLogManager(); // 로그 매니저

    StreamSubscription<DocumentSnapshot>? _boardStream;

    String localName = "";
    int localcode = 0;
    bool _isLoading = true;
    bool _isMoving = false;

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

    Future<void> showWarningIfNeeded(BuildContext context) async {
      final checker = WarningChecker();
      final result = await checker.check();
      if (result == null) return;
      if(result != null){
        if(WarningDialog.canShow(result.players,result.type)){
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (_) => WarningDialog(players: result.players, type: result.type),
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
      _boardStream?.cancel();
      super.dispose();
    }

    void _triggerMoneyEffect(String userKey, int amount) {
      setState(() {
        _moneyEffects[userKey] = amount > 0 ? "+$amount" : "$amount";
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() { _moneyEffects[userKey] = null; });
        }
      });
    }

    Future<void> _onDiceRoll(int val1, int val2) async {
      //-- 로그 기록 --
      int currentTurnNum = 21 - totalTurn;
      int diceSum = val1 + val2;
      _logManager.startTurnLog(currentTurnNum, diceSum);
      //-------------------
      bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
      if (isTraveling) {
        setState(() { players["user$currentTurn"]["isTraveling"] = false; });
        await fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
        _triggerHighlight(currentTurn, "trip");
        return;
      }

      int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

      if (islandCount > 0) {
        bool isDouble = (val1 == val2);
        if (isDouble) {
          print("🎲 더블! 무인도 탈출 성공!");
          _logManager.addActionLog("더블! 무인도 탈출 성공 🎉");
          await fs.collection("games").doc("users").update({ "user$currentTurn.islandCount": 0 });
          setState(() { players["user$currentTurn"]["islandCount"] = 0; });
          movePlayer(val1 + val2, currentTurn, false);
        } else {
          print("🎲 더블 아님. 무인도 잔류.");
          _logManager.addActionLog("탈출 실패 (남은 횟수: ${islandCount - 1})");
          int newCount = islandCount - 1;
          await fs.collection("games").doc("users").update({ "user$currentTurn.islandCount": newCount });
          setState(() { players["user$currentTurn"]["islandCount"] = newCount; });
          _nextTurn();
        }
        return;
      }

      int total = val1 + val2;
      bool isDouble = (val1 == val2);
      movePlayer(total, currentTurn, isDouble);
    }

    Future<void> _checkAndStartTurn() async {
      String type = players["user$currentTurn"]?["type"] ?? "N";

      if (type == "N" || type == "D" || type == "BD") {
        _nextTurn();
        return;
      }

      // 🔥 [수정됨] GameRules 사용
      await _checkWinCondition(currentTurn);

      bool needUpdate = false;
      WriteBatch batch = fs.batch();

      boardList.forEach((key, val) {
        if (val is Map && val['type'] == 'land') {
          int owner = int.tryParse(val['owner'].toString()) ?? 0;
          double multiply = (val['multiply'] as num? ?? 1.0).toDouble();

          if (owner == currentTurn && multiply < 1.0) {
            batch.update(fs.collection("games").doc("board"), { "$key.multiply": 1 });
            val['multiply'] = 1;
            needUpdate = true;
          }
        }
      });

      if (needUpdate) {
        await batch.commit();
        setState(() {});
      }

      int restCount = players["user$currentTurn"]["restCount"] ?? 0;

      if (restCount > 0) {
        int currentTurnNum = 21 - totalTurn;
        _logManager.startTurnLog(currentTurnNum, 0); // 주사위 0
        _logManager.addActionLog("💤 한 턴 쉬어갑니다.");
        
        await fs.collection("games").doc("users").update({ "user$currentTurn.restCount": 0 });
        setState(() { players["user$currentTurn"]["restCount"] = 0; });

        if (type != "B") {
          await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                });
                return Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFFFDF5E6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFC0A060), width: 4), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2))]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 40, color: Colors.brown),
                        const SizedBox(height: 10),
                        const Text("한턴 쉬어갑니다~", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown), textAlign: TextAlign.center),
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

      int islandCount = players["user$currentTurn"]["islandCount"] ?? 0;

      if (islandCount > 0) {
        if (type != 'B') {
          if(players["user$currentTurn"]["card"] == "escape"){
            final result = await showDialog(context: context, useSafeArea: false, builder: (context)=>CardUseDialog(user: currentTurn));
            if(result) {
              _logManager.addActionLog("🎫 무인도 탈출권 사용 (탈출 성공!)");
              fs.collection("games").doc("users").update({ "user$currentTurn.card" : "N" });
              await _readPlayer();
              return;
            }
          }
          final bool? paidToEscape = await showDialog<bool>(context: context, barrierDismissible: false, builder: (context) => IslandDialog(user: currentTurn));
          if (paidToEscape == true) {
            await fs.collection("games").doc("users").update({ "user$currentTurn.islandCount": 0 });
            setState(() { players["user$currentTurn"]["islandCount"] = 0; });
            _triggerMoneyEffect("user$currentTurn", -1000000);
            await _readPlayer();
          }
        } else {
          print("🤖 봇 무인도 탈출 시도 (주사위 굴림)");
        }
      }

      bool isTraveling = players["user$currentTurn"]["isTraveling"] ?? false;
      if (isTraveling) {
        setState(() { players["user$currentTurn"]["isTraveling"] = false; });
        await fs.collection("games").doc("users").update({"user$currentTurn.isTraveling": false});
        _triggerHighlight(currentTurn, "trip");
        return;
      }

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
      setState(() {
        _highlightOwner = (event == "trip" || event == "earthquake") ? -1 : player;
        eventNow = event;
      });
      _glowController.repeat(reverse: true);
    }

    Future<void> _stopHighlight(int index, String event) async {
      setState(() { _highlightOwner = null; });
      _glowController.stop();
      _glowController.reset();

      if(event == "start"){
        int myLevel = players["user$_eventPlayer"]["level"] ?? 1;
        int buildingLevel = boardList["b$index"]["level"] ?? 0;

        if (myLevel > buildingLevel) {
          final result = await showDialog(
              context: context, barrierDismissible: false,
              builder: (context) { return ConstructionDialog(user: _eventPlayer, buildingId: index); }
          );
          if (result != null && result is Map) {
            setState(() {
              if (boardList["b$index"] == null) boardList["b$index"] = {};
              boardList["b$index"]["level"] = result["level"];
              boardList["b$index"]["owner"] = result["user"];
            });
            await _checkWinCondition(_eventPlayer);
          }
        }
        await _readPlayer(); await rankChange(); setState(() {}); _handleTurnEnd();

      } else if(event == "festival"){
        String targetName = boardList["b$index"]?['name'] ?? "알 수 없음";
        _logManager.addActionLog("🎉 $targetName에 축제 개최");
        
        if(itsFestival != 0){
          await fs.collection("games").doc("board").update({"b$itsFestival.isFestival" : false});
        }
        await fs.collection("games").doc("board").update({"b$index.isFestival" : true});
        setState(() { itsFestival = index; });
        await _readLocal(); _handleTurnEnd();

      } else if (event == "trip"){
        if (players["user$_eventPlayer"]["isTraveling"] == true) {
          setState(() { players["user$_eventPlayer"]["isTraveling"] = false; });
          await fs.collection("games").doc("users").update({ "user$_eventPlayer.isTraveling": false });
        }
        // ...
        int currentTurnNum = 21 - totalTurn;
        _logManager.startTurnLog(currentTurnNum, 0); 
        _logManager.addActionLog("✈️ 세계여행으로 이동");
        _movePlayerTo(index, _eventPlayer);

      } else if (event == "earthquake" || event == "storm") {
        String targetName = boardList["b$index"]?['name'] ?? "알 수 없음";
        _logManager.addActionLog("📉 $targetName 공격 ($event)");
        await _executeEarthquake(index);
        _handleTurnEnd();

      } else if (event == "priceDown") {
        String targetName = boardList["b$index"]?['name'] ?? "알 수 없음";
        _logManager.addActionLog("🏷️ $targetName 통행료 할인");
        await fs.collection("games").doc("board").update({ "b$index.multiply": 0.5 });
        setState(() { if(boardList["b$index"] != null) boardList["b$index"]["multiply"] = 0.5; });
        _handleTurnEnd();
      }
    }

    Future<void> _executeEarthquake(int targetIndex) async {
      String tileKey = "b$targetIndex";
      if (boardList[tileKey] == null) return;

      int currentLevel = boardList[tileKey]["level"] ?? 0;
      final batch = fs.batch();

      // 🔥 [수정됨] GameRules 사용
      int newLevel = GameRules.getLevelAfterAttack(currentLevel);
      int price = boardList[tileKey]["tollPrice"];
      String userNum = boardList[tileKey]["owner"];
      int userMoney = players["user$userNum"]["money"];
      int levelMult = 0;
      switch (newLevel) {
        case 0: levelMult = 1; break;
        case 1: levelMult = 2; break;
        case 2: levelMult = 4; break;
        case 3: levelMult = 8; break;
      }
      price = price * levelMult;
      if (newLevel == 0) {
        batch.update(fs.collection("games").doc("board"), {
          "$tileKey.level": 0, "$tileKey.owner": "N", "$tileKey.multiply": 1, "$tileKey.isFestival": false,
        });
        setState(() {
          boardList[tileKey]["level"] = 0; boardList[tileKey]["owner"] = "N"; boardList[tileKey]["isFestival"] = false;
        });
      } else {
        batch.update(fs.collection("games").doc("board"), { "$tileKey.level": newLevel });
        setState(() { boardList[tileKey]["level"] = newLevel; });
      }
      await fs.collection("games").doc("users").update({"user$userNum.money" : userMoney - price});
      await batch.commit();
      await _readLocal(); await _readPlayer();
      _triggerMoneyEffect("user$userNum", price);
      print("지진/태풍 발생! $targetIndex번 땅 공격 완료.");
    }

    Future<void> _checkWinCondition(int player) async {
      print("승리조건체크");
      await showWarningIfNeeded(context);

      // 🔥 [수정됨] GameRules로 로직 위임 (코드가 30줄 -> 3줄로 감소)
      String? winType = GameRules.checkWinCondition(boardList, player);

      if (winType != null) {
        _gameOver(winType, winnerIndex: player);
      }
    }

    void _handleTurnEnd() async {
      if (_lastIsDouble) {
        doubleCount++;
        if (doubleCount >= 3) {
          setState(() { players["user$_eventPlayer"]["position"] = 7; players["user$_eventPlayer"]["islandCount"] = 3; });
          await fs.collection("games").doc("users").update({ "user$_eventPlayer.position": 7, "user$_eventPlayer.islandCount": 3 });
          _nextTurn();
        }
      } else {
        _nextTurn();
      }
    }

    Future<void> _setLocal() async {
      int random = Random().nextInt(localList.length);
      if(mounted) {
        setState(() { localName = localList[random].keys.first; localcode = localList[random][localName]['ccbaCtcd']; });
      }

      var heritage = await _heritageRepo.loadHeritage(localcode, localName);
      if(mounted) setState(() { heritageList = heritage; });

      var detail = await _heritageRepo.loadHeritageDetail(heritage);
      if(mounted) setState(() { heritageList = detail; });

      await _heritageRepo.updateGameDataWithHeritage(heritageList);

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
      setState(() { _isMoving = true; });
      _lastIsDouble = isDouble;
      String playerType = players["user$player"]["type"] ?? "P";
      int currentPos = players["user$player"]["position"];
      int nextPos = currentPos + steps;

      for (int i = 1; i <= steps; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        int tempPos = currentPos + i;

        if (tempPos == 28) {
          int level = players["user$player"]["level"];
          int currentMoney = players["user$player"]["money"];
          int currentTotalMoney = players["user$player"]["totalMoney"];
          int salary = 1000000;

          if(level < 4){
            await fs.collection("games").doc("users").update({
              "user$player.level": level + 1, "user$player.money": currentMoney + salary, "user$player.totalMoney": currentTotalMoney + salary
            });
            setState(() {
              players["user$player"]["level"] = level + 1; players["user$player"]["money"] = currentMoney + salary; players["user$player"]["totalMoney"] = currentTotalMoney + salary;
            });
          } else {
            await fs.collection("games").doc("users").update({
              "user$player.money": currentMoney + salary, "user$player.totalMoney": currentTotalMoney + salary
            });
            setState(() {
              players["user$player"]["money"] = currentMoney + salary; players["user$player"]["totalMoney"] = currentTotalMoney + salary;
            });
          }
          _logManager.addActionLog("💵 출발지 통과 (월급 +${_formatMoney(salary)})");
          _triggerMoneyEffect("user$player", salary);
        }
        setState(() { players["user$player"]["position"] = tempPos % 28; });
      }

      setState(() { _isMoving = false; });
      int changePosition = nextPos % 28;
      await fs.collection("games").doc("users").update({"user$player.position": changePosition});

      String tileKey = "b$changePosition";
      // -- 로그 기록용(도착한 곳) ---
      String landName = boardList[tileKey]?['name'] ?? "알 수 없음";
      _logManager.setArrivalLog(landName);
      // -------------------------------
      bool forceNextTurn = false;

      if(boardList[tileKey] != null && boardList[tileKey]["type"] == "land"){
        int owner = int.tryParse(boardList[tileKey]["owner"].toString()) ?? 0;
        int buildLevel = boardList[tileKey]["level"] ?? 0;
        int tollPrice = boardList[tileKey]["tollPrice"] ?? 0;

        if(owner == player) {
          if (playerType == 'B') {
            await _botBuild(player, changePosition);
          } else {
            int myLevel = players["user$player"]["level"] ?? 1;
            int currentBuildingLevel = (boardList[tileKey] != null) ? (boardList[tileKey]["level"] ?? 0) : 0;

            if (myLevel > currentBuildingLevel) {
              final result = await showDialog(
                  context: context, barrierDismissible: false,
                  builder: (context) { return ConstructionDialog(user: player, buildingId: changePosition); }
              );
              if (result != null && result is Map) {
                int level = result['level'] ?? 1;
                String levelText = (level >= 4) ? "랜드마크" : "$level단계";
                _logManager.addActionLog("🏛️ $levelText 업그레이드");
                
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

          // 🔥 [수정됨] GameRules.calculateToll 사용
          int finalToll = GameRules.calculateToll(
            basePrice: boardList[tileKey]["tollPrice"] ?? 0,
            level: buildLevel,
            multiply: (boardList[tileKey]["multiply"] as num? ?? 0).toDouble(),
            isFestival: itsFestival == changePosition,
            isDoubleTollItem: players["user$player"]["isDoubleToll"] ?? false,
          );

          if(playerType != 'B' && players["user$player"]["card"] == "shield"){
            final bool? useShield = await showDialog(context: context, useSafeArea: false, barrierDismissible: false, builder: (context) => CardUseDialog(user: player, tollPrice: finalToll));
            if(useShield == true){
              isShieldUsed = true;
              _logManager.addActionLog("🛡️ VIP 카드 사용 (통행료 면제)");
              await fs.collection("games").doc("users").update({ "user$player.card" : "N" });
              setState(() { players["user$player"]["card"] = "N"; });
            }
          }
          if (playerType != 'B' && !isShieldUsed) {
            bool quizResult = await DiscountQuizManager.startDiscountQuiz(context, "통행료");
            if (quizResult) {
              finalToll = (finalToll / 2).round();
              _logManager.addActionLog("💡 찬스 퀴즈 정답! 통행료 50% 할인 🎉");
            } else {
              _logManager.addActionLog("❌ 찬스 퀴즈 오답... 할인 실패");
            }
          }

          if (isShieldUsed) finalToll = 0;
          int myMoney = players["user$player"]["money"];

          if(finalToll > 0) {
            _logManager.addActionLog("💸 통행료 지불 (-${_formatMoney(finalToll)}) → user$owner");
            
            if(myMoney - finalToll < 0){
              bool isBankrupt = false;
              if (playerType == 'B') {
                isBankrupt = true;
              } else {
                final result = await showDialog(context: context, barrierDismissible: false, builder: (context) { return BankruptDialog(lackMoney: finalToll - myMoney, reason: "toll", user: player); });
                await _readPlayer();
                if (result != null && result is Map && result["result"] == "BANKRUPT") isBankrupt = true;
                else if (result == "SURVIVED") { await _readPlayer(); myMoney = players["user$player"]["money"]; }
              }

              if (isBankrupt) {
                _logManager.addActionLog("💀 파산하였습니다! 모든 자산을 처분합니다.");
                _logManager.addLog("user$owner", "🎊 상대방(user$player)이 파산하여 보상금을 획득했습니다!");

                // 파산 처리 로직 (이전과 동일)
                int remainingMoney = myMoney > 0 ? myMoney : 0;
                int survivorCount = 0;
                for(int i=1; i<=4; i++){ String t = players["user$i"]?["type"] ?? "N"; if(t != "N" && t != "D" && t != "BD") survivorCount++; }
                int myFixedRank = survivorCount;
                WriteBatch batch = fs.batch();
                String bankruptType = (playerType == 'B') ? "BD" : "D";
                batch.update(fs.collection("games").doc("users"), { "user$player.money": 0, "user$player.totalMoney": 0, "user$player.type": bankruptType, "user$player.rank": myFixedRank, });
                batch.update(fs.collection("games").doc("users"), { "user$owner.money": FieldValue.increment(remainingMoney), "user$owner.totalMoney": FieldValue.increment(remainingMoney), });
                final boardSnap = await fs.collection("games").doc("board").get();
                if (boardSnap.exists) {
                  boardSnap.data()!.forEach((key, val) { if (val is Map && val["owner"].toString() == player.toString()) { batch.update(fs.collection("games").doc("board"), { "$key.owner": "N", "$key.level": 0, "$key.multiply": 1, "$key.isFestival": false }); } });
                }
                await batch.commit();
                _triggerMoneyEffect("user$owner", remainingMoney);
                _triggerMoneyEffect("user$player", -remainingMoney);
                await _readPlayer(); await _readLocal(); await rankChange();
                _nextTurn();
                return;
              }
            }

            await fs.collection("games").doc("users").update({
              "user$player.money": players["user$player"]["money"] - finalToll,
              "user$player.totalMoney": players["user$player"]["totalMoney"] - finalToll,
              "user$owner.money": players["user$owner"]["money"] + finalToll,
              "user$owner.totalMoney": players["user$owner"]["totalMoney"] + finalToll
            });

            String landNameForOwner = boardList[tileKey]?['name'] ?? "알 수 없음";
            _logManager.addLog("user$owner", "💰 통행료 획득 (+${_formatMoney(finalToll)}) - $landNameForOwner");

            if (players["user$player"]["isDoubleToll"] == true) {
              fs.collection("games").doc("users").update({"user$player.isDoubleToll" : false});
            }

            setState(() {
              players["user$player"]["money"] -= finalToll;
              players["user$player"]["totalMoney"] -= finalToll;
              players["user$owner"]["money"] += finalToll;
              players["user$owner"]["totalMoney"] += finalToll;
              if (players["user$player"]["isDoubleToll"] == true) players["user$player"]["isDoubleToll"] = false;
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
                  tx.update(fs.collection("games").doc("users"), { "user$player.money": FieldValue.increment(-takeoverCost), });
                  tx.update(fs.collection("games").doc("users"), { "user$owner.money": FieldValue.increment(takeoverCost), });
                  tx.update(fs.collection("games").doc("board"), { "b$changePosition.owner": player, });
                });
                _triggerMoneyEffect("user$player", -takeoverCost);
                _triggerMoneyEffect("user$owner", takeoverCost);
                await _readPlayer(); await _readLocal();
                await _botBuild(player, changePosition);
              }
            } else {
              final bool? takeoverSuccess = await showDialog(context: context, barrierDismissible: false, builder: (context) { return TakeoverDialog(buildingId: changePosition, user: player); });
              if (takeoverSuccess == true) {
                int levelMult = 0;
                switch (buildLevel) {
                  case 1: levelMult = 2; break;
                  case 2: levelMult = 6; break;
                  case 3: levelMult = 14; break;
                  case 4: levelMult = 30; break;
                }
                await _checkWinCondition(player);
                setState(() { if (boardList[tileKey] == null) boardList[tileKey] = {}; boardList[tileKey]["owner"] = player; });
                await _readPlayer(); await _readLocal();

                // ✅ 인수 비용 계산 및 변수 정의
                int takeoverPrice = levelMult * tollPrice;

                _triggerMoneyEffect("user$player", -takeoverPrice);
                _triggerMoneyEffect("user$owner", takeoverPrice);

                _logManager.addLog("user$owner", "💸 내 땅 인수 당함 (+${_formatMoney(takeoverPrice)}) - ${boardList[tileKey]?['name']}");

                _logManager.addActionLog("🏗️ 도시 인수 (-${_formatMoney(takeoverPrice)})");

                if (!mounted) return;
                int myLevel = players["user$player"]["level"] ?? 1;
                int currentBuildingLevel = (boardList[tileKey] != null) ? (boardList[tileKey]["level"] ?? 0) : 0;
                if (myLevel > currentBuildingLevel) {
                  final constructionResult = await showDialog(context: context, barrierDismissible: false, builder: (context) { return ConstructionDialog(user: player, buildingId: changePosition); });
                  if (constructionResult != null) {
                    setState(() { boardList[tileKey]["level"] = constructionResult["level"]; boardList[tileKey]["owner"] = constructionResult["user"]; });
                    await _readPlayer(); await _checkWinCondition(player); await _readLocal();
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
              final result = await showDialog(context: context, barrierDismissible: false, builder: (context) { return ConstructionDialog(user: player, buildingId: changePosition); });
              if (result != null && result is Map) {
                int cost = result['totalCost'] ?? 0;
                int level = result['level'] ?? 1;
                String levelText = (level >= 4) ? "랜드마크" : "$level단계";
                _logManager.addActionLog("🏛️ $levelText 건설 (-${_formatMoney(cost)})");
                
                setState(() {
                  if (boardList[tileKey] == null) boardList[tileKey] = {};
                  boardList[tileKey]["level"] = result["level"];
                  boardList[tileKey]["owner"] = result["user"];
                });
                await _readPlayer(); await _checkWinCondition(player);
              }
            }
          }
        }
      }
      // 국세청, 축제 등 특수 타일 로직은 그대로 유지 (분량이 많아 생략 없이 기존 코드 유지됨)
      else if(changePosition == 26){
        if (playerType == 'B') {
          int myMoney = players["user$player"]["money"];
          int tax = (myMoney * 0.1).round();
          await fs.collection("games").doc("users").update({ "user$player.money": FieldValue.increment(-tax), "user$player.totalMoney": FieldValue.increment(-tax), });
          _logManager.addActionLog("세금 납부 (-${_formatMoney(tax)})");
          _triggerMoneyEffect("user$player", -tax);
        } else {
          int tax = await showDialog(context: context, builder: (context)=> TaxDialog(user: player));
          if(tax > 0){
            _logManager.addActionLog("세금 납부 (-${_formatMoney(tax)})");
            _triggerMoneyEffect("user$player", -tax);
          }
        }
        await _readPlayer();
      }
      else if(changePosition == 14){
        if(playerType != 'B') {
          bool hasMyLand = false;
          boardList.forEach((key, val) { int owner = int.tryParse(val['owner'].toString()) ?? 0; if(val['type'] == 'land' && owner == player) hasMyLand = true; });
          if(hasMyLand) { _triggerHighlight(player, "festival"); return; }
          else {
            await showDialog(
              context: context, barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                Future.delayed(const Duration(seconds: 2), () { if (dialogContext.mounted) Navigator.of(dialogContext).pop(); });
                return Dialog(backgroundColor: Colors.transparent, elevation: 0, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFFDF5E6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFC0A060), width: 4), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2))]), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.info_outline, size: 40, color: Colors.brown), const SizedBox(height: 10), const Text("축제를 열 땅이 없습니다!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown), textAlign: TextAlign.center)])));
              },
            );
          }
        }
      }
      else if(changePosition == 0){
        if (playerType != 'B') {
          bool hasUpgradableLand = false;
          boardList.forEach((key, val) { int owner = int.tryParse(val['owner'].toString()) ?? 0; int level = val['level'] ?? 0; if(val['type'] == 'land' && owner == player && level < 4) hasUpgradableLand = true; });
          if(hasUpgradableLand) { _triggerHighlight(player, "start"); return; }
        }
      }
      else if(changePosition == 21){
        if (playerType != 'B') {
          setState(() { players["user$player"]["isTraveling"] = true; });
          await fs.collection("games").doc("users").update({"user$player.isTraveling": true});
          forceNextTurn = true;
        }
      }
      else if(changePosition == 7){
        forceNextTurn = true;
        await fs.collection("games").doc("users").update({ "user$player.islandCount" : 3 });
        await _readPlayer();
      }
      else if ([3, 10, 17, 24].contains(changePosition)) {
        if (playerType != 'B') {
          QuizQuestion? question = await QuizRepository.getRandomQuiz();
          bool isCorrect = false;
          int? selectedIndex;
          if (question != null && mounted) {
            await showDialog(context: context, barrierDismissible: false, builder: (context) => QuizDialog(question: question, onQuizFinished: (index, correct) { selectedIndex = index; isCorrect = correct; }));
            if (mounted) await showDialog(context: context, barrierDismissible: false, builder: (context) => QuizResultPopup(isCorrect: isCorrect, question: question, selectedIndex: selectedIndex ?? -1));
          }
          if (mounted) {
            final String? actionResult = await showDialog<String>(useSafeArea: false, context: context, barrierDismissible: false, builder: (context) => ChanceCardQuizAfter(quizEffect: isCorrect, storedCard: players["user$player"]["card"], userIndex: player));
            if (actionResult != null) {

              if (actionResult == "c_trip") { 
                _logManager.addActionLog("✨ 찬스카드: 세계여행 당첨!");
                _movePlayerTo(21, player); return; 
              }
              else if (actionResult == "c_festival") {
                _logManager.addActionLog("✨ 찬스카드: 축제 개최권 획득");
                // ... (축제 로직) ...
                bool hasMyLand = false;
                boardList.forEach((key, val) { if (val is Map && val['type'] == 'land') { int owner = int.tryParse(val['owner'].toString()) ?? 0; if (owner == player) hasMyLand = true; } });
                if (hasMyLand) { _triggerHighlight(player, "festival"); return; }
                else {
                  await showDialog(context: context, barrierDismissible: false, builder: (ctx) { Future.delayed(const Duration(seconds: 2), () { if (ctx.mounted) Navigator.of(ctx).pop(); }); return const Dialog(backgroundColor: Colors.transparent, elevation: 0, child: Text("축제를 열 땅이 없습니다!", textAlign: TextAlign.center)); });
                }
              } else if (actionResult == "c_start") { 
                _logManager.addActionLog("✨ 찬스카드: 시작점으로 이동");
                _movePlayerTo(0, player); return; 
              }
              else if (actionResult == "c_earthquake") {
                _logManager.addActionLog("✨ 찬스카드: 지진 공격권 획득");
                // ... (지진 로직) ...
                List<int> validTargets = [];
                boardList.forEach((key, val) { if (val is Map && val['type'] == 'land') { int owner = int.tryParse(val['owner'].toString()) ?? 0; int level = val['level'] ?? 0; if (owner != 0 && owner != player && level < 4) validTargets.add(val['index']); } });
                if (validTargets.isEmpty) {
                  await showDialog(context: context, barrierDismissible: false, builder: (ctx) { Future.delayed(const Duration(seconds: 2), () { if (ctx.mounted) Navigator.of(ctx).pop(); }); return const Dialog(backgroundColor: Colors.transparent, elevation: 0, child: Text("공격할 상대 건물이 없습니다!", textAlign: TextAlign.center)); });
                } else { _triggerHighlight(player, "earthquake"); return; }
              } else if (actionResult == "c_bonus") {
                _logManager.addActionLog("✨ 찬스카드: 보너스 300만 획득");
                await fs.collection("games").doc("users").update({ "user$player.money" : players["user$player"]["money"] + 3000000, "user$player.totalMoney" : players["user$player"]["totalMoney"] + 3000000 });
                _triggerMoneyEffect("user$player", 3000000);
              } else if (actionResult == "d_island") { 
                _logManager.addActionLog("🌩️ 함정카드: 무인도로 강제 이동");
                _movePlayerTo(7, player); 
              }
              else if (actionResult == "d_tax") { 
                _logManager.addActionLog("🌩️ 함정카드: 국세청으로 강제 이동");
                _movePlayerTo(26, player); 
              }
              else if (actionResult == "d_rest") { 
                 _logManager.addActionLog("🌩️ 함정카드: 한 턴 휴식");
                 await fs.collection("games").doc("users").update({"user$player.restCount": 1}); 
              }
              else if (actionResult == "d_priceUp") { 
                 _logManager.addActionLog("🌩️ 함정카드: 보유 땅 통행료 2배 적용");
                 await fs.collection("games").doc("users").update({"user$player.isDoubleToll": true}); 
              }
              else if (actionResult == "d_storm") {
                _logManager.addActionLog("🌩️ 함정카드: 태풍 공격권 획득");
                bool hasMyLand = false;
                boardList.forEach((key, val) { if (val is Map && val['type'] == 'land') { int owner = int.tryParse(val['owner'].toString()) ?? 0; if (owner == player) hasMyLand = true; } });
                if (hasMyLand) { _triggerHighlight(player, "storm"); return;  }
                else {
                  await showDialog(context: context, barrierDismissible: false, builder: (ctx) { Future.delayed(const Duration(seconds: 2), () { if (ctx.mounted) Navigator.of(ctx).pop(); }); return const Dialog(backgroundColor: Colors.transparent, elevation: 0, child: Text("태풍을 일으킬 땅이 없습니다!", textAlign: TextAlign.center)); });
                }
              }
              else if (actionResult == "d_priceDown") {
                _logManager.addActionLog("🌩️ 함정카드: 보유 땅 통행료 할인");
                List<int> myLands = [];
                boardList.forEach((key, val) { if (val['type'] == 'land') { int owner = int.tryParse(val['owner'].toString()) ?? 0; if (owner == player) myLands.add(val['index']); } });
                if (myLands.isEmpty) {
                  await showDialog(context: context, builder: (ctx) { Future.delayed(const Duration(seconds: 2), () { if (ctx.mounted) Navigator.of(ctx).pop(); }); return const Dialog(backgroundColor: Colors.transparent, elevation: 0, child: Text("할인할 내 땅이 없습니다!", textAlign: TextAlign.center)); });
                } else { _triggerHighlight(player, "priceDown"); return; }
              } else if (actionResult == "d_move") {
                _logManager.addActionLog("🌩️ 함정카드: 랜덤 지역으로 이동");
                Random ran = Random(); int currentPos = players["user$player"]["position"]; int randomPos = ran.nextInt(28);
                while(randomPos == currentPos) { randomPos = ran.nextInt(28); }
                Future.delayed(const Duration(milliseconds: 500), () { if (mounted) _movePlayerTo(randomPos, player); });
                return;
              }
              await _readPlayer();
            }
          }
        }
      }

      _setPlayer();

      if (forceNextTurn || !isDouble) {
        _nextTurn();
      } else {
        _logManager.addActionLog("🎲 더블! 한 번 더!");
        _logManager.commitLog("user$player");

        doubleCount++;
        if (doubleCount >= 3) {
          setState(() { players["user$player"]["position"] = 7; });
          await fs.collection("games").doc("users").update({ "user$player.position": 7, "user$player.islandCount": 3 });
          _logManager.addActionLog("🚨 3연속 더블 -> 무인도 이동");
          _nextTurn();
        } else {
          if (playerType == 'B') {
            print("🤖 봇 더블! 주사위 다시 굴립니다.");
            Future.delayed(const Duration(seconds: 2), () {
              if (!mounted) return;
              int d1 = Random().nextInt(6) + 1; int d2 = Random().nextInt(6) + 1;
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
      if (currentBuildingLevel == 3) { maxLimit = 4; } else { maxLimit = (playerLapLevel >= 3) ? 3 : playerLapLevel; }

      for (int l = currentBuildingLevel + 1; l <= maxLimit; l++) {
        if (money >= totalCost + costPerLevel) { totalCost += costPerLevel; targetLevel = l; } else { break; }
      }

      if (targetLevel > currentBuildingLevel) {
        await fs.runTransaction((tx) async {
          tx.update(fs.collection("games").doc("users"), { "user$player.money": FieldValue.increment(-totalCost), });
          tx.update(fs.collection("games").doc("board"), { "$tileKey.level": targetLevel, "$tileKey.owner": player, });
        });
        setState(() { boardList[tileKey]["level"] = targetLevel; boardList[tileKey]["owner"] = player; });

        String levelText = (targetLevel >= 4) ? "랜드마크" : "$targetLevel단계";
        _logManager.addActionLog("🤖 $levelText 건설 (-${_formatMoney(totalCost)})");
        
        _triggerMoneyEffect("user$player", -totalCost);
        await _readPlayer(); await rankChange(); setState(() {}); await _checkWinCondition(player);
      }
    }

    void _nextTurn() {
      _logManager.commitLog("user$currentTurn");
      int survivors = 0;
      int lastSurvivorIndex = 0;
      for (int i = 1; i <= 4; i++) { String type = players["user$i"]?["type"] ?? "N"; if (type != "N" && type != "D" && type != "BD") { survivors++; lastSurvivorIndex = i; } }
      if (survivors <= 1) { _gameOver("bankruptcy", winnerIndex: lastSurvivorIndex); return; }

      setState(() {
        doubleCount = 0; int nextPlayer = currentTurn; int safetyLoop = 0;
        do {
          if (nextPlayer == 4) { nextPlayer = 1; totalTurn--; if (totalTurn == 0) { _gameOver("turn_limit"); return; } } else { nextPlayer++; }
          safetyLoop++;
          String nextType = players["user$nextPlayer"]?["type"] ?? "N";
          if (nextType != "N" && nextType != "D" && nextType != "BD") { break; }
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
        if (players["user$i"] != null && players["user$i"]["type"] != "N" && players["user$i"]["type"] != "D" && players["user$i"]["type"] != "BD") {
          tempUsers.add({ "key": "user$i", "totalMoney": players["user$i"]["totalMoney"] ?? 0, "money": players["user$i"]["money"] ?? 0, });
        }
      }
      tempUsers.sort((a, b) { int compare = b["totalMoney"].compareTo(a["totalMoney"]); if (compare == 0) { return b["money"].compareTo(a["money"]); } return compare; });
      for (int i = 0; i < tempUsers.length; i++) { String key = tempUsers[i]["key"]; players[key]["rank"] = i + 1; }
    }

    Future<void> _readPlayer() async{ final snap = await fs.collection("games").doc("users").get(); setState(() { players = snap.data() ?? {}; }); }
    Future<void> _readLocal() async{ final snap = await fs.collection("games").doc("board").get(); if(snap.exists && snap.data() != null){ if(mounted) { setState(() { boardList = snap.data() as Map<String, dynamic>; }); } } }

    // ================= 플레이어 상세 정보창 팝업 함수 추가 =================
    void _showPlayerDetail(String key, Color color) {
      showDialog(
        context: context,
        builder: (context) => PlayerDetailPopup(
          playerKey: key,
          playerData: players[key] ?? {},
          boardData: boardList,
          playerColor: color,
          logs: _logManager.getLogs(key),
        ),
      );
    }

    // ================= 종료 확인 다이얼로그 함수 =================
    Future<void> _showExitDialog() async {
      bool? exit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("게임 종료", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          content: const Text("게임을 종료하고 메인 화면으로 돌아가시겠습니까?\n현재 진행 상황은 저장되지 않습니다."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소", style: TextStyle(color: Colors.grey))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("종료", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: const Color(0xFFFDF5E6),
        ),
      );
      if (exit == true && mounted) {
        context.go('/main');
      }
    }

    void _showStartDialog(String localName) {
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
        Future.delayed(const Duration(seconds: 3), () { if (context.mounted) Navigator.of(context).pop(); });
        return AlertDialog(title: const Text("게임 시작" ,textAlign: TextAlign.center), content: SizedBox(width: double.infinity * 0.5, child: Text("이번 문화재 보유 지역은\n'$localName' 입니다!", textAlign: TextAlign.center,)));
      },
      );
    }

    Map<String, double> _getTilePosition(int index, double boardSize, double tileSize) {
      double top = 0; double left = 0;
      if (index >= 0 && index <= 7) { top = boardSize - tileSize; left = boardSize - tileSize - (index * tileSize); }
      else if (index >= 8 && index <= 14) { left = 0; top = boardSize - tileSize - ((index - 7) * tileSize); }
      else if (index >= 15 && index <= 21) { top = 0; left = (index - 14) * tileSize; }
      else if (index >= 22 && index <= 27) { left = boardSize - tileSize; top = (index - 21) * tileSize; }
      return {'top': top, 'left': left};
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
        backgroundColor: Colors.transparent, elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFFFDF5E6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFC0A060), width: 4), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.info_outline, size: 40, color: Colors.brown), const SizedBox(height: 10), Text(eventText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown), textAlign: TextAlign.center)]),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      if (_isLoading) {
        return const LoadingScreen(
          isOverlay: true,
          message: "보드판을 구성하고 있습니다...",
          type: LoadingType.dice,
        );
      }
      final double screenHeight = MediaQuery.of(context).size.height;
      final double boardSize = screenHeight * 0.9;
      final double tileSize = boardSize / 8;

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _showExitDialog();
        },
        child: Scaffold(
          backgroundColor: Colors.grey[900],
          body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(width: double.infinity, height: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/board-background.PNG'), fit: BoxFit.cover))),
              SizedBox(
                width: boardSize, height: boardSize,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: boardSize * 0.75, height: boardSize * 0.75,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: _highlightOwner == null
                            ? (_isMoving ? const SizedBox() : DiceApp(key: diceAppKey, turn: currentTurn, totalTurn: totalTurn, isBot: (players["user$currentTurn"]?["type"] == "B"), onRoll: (int v1, int v2) => _onDiceRoll(v1, v2)))
                            : _showEventDialog(),
                      ),
                    ),

                    ...List.generate(28, (index) {
                      Map<String, double> pos = _getTilePosition(index, boardSize, tileSize);
                      double? pTop = pos['top'] == 0 && (index < 15 || index > 21) ? null : pos['top'];
                      double? pLeft = pos['left'] == 0 && (index < 8 || index > 22) ? null : pos['left'];
                      double? finalTop, finalBottom, finalLeft, finalRight;
                      if (index >= 0 && index <= 7) { finalBottom = 0; finalRight = index * tileSize; }
                      else if (index >= 8 && index <= 14) { finalLeft = 0; finalBottom = (index - 7) * tileSize; }
                      else if (index >= 15 && index <= 21) { finalTop = 0; finalLeft = (index - 14) * tileSize; }
                      else if (index >= 22 && index <= 27) { finalRight = 0; finalTop = (index - 21) * tileSize; }

                      bool shouldGlow = false;
                      var tData = boardList["b$index"];
                      int owner = int.tryParse(tData?["owner"].toString() ?? "0") ?? 0;
                      int level = tData?["level"] ?? 0;

                      if (_highlightOwner == -1) {
                        if (eventNow == "trip") { if(index != 21) shouldGlow = true; }
                        else if (eventNow == "earthquake") { if (owner != 0 && owner != _eventPlayer && level < 4) shouldGlow = true; }
                      } else if (_highlightOwner != null && _highlightOwner == owner) {
                        if (eventNow == "start") { if (level < 4) shouldGlow = true; } else { shouldGlow = true; }
                      }

                      void handleTap() async {
                        if (shouldGlow) { _stopHighlight(index, eventNow); }
                        else {
                          if (boardList["b$index"] != null && boardList["b$index"]["type"] == "land") {
                            final result = await showDialog(context: context, builder: (context) { return DetailPopup(boardNum: index,onNext: (){},); });
                            if(result != null){
                              Map<String, dynamic> fullData = Map<String, dynamic>.from(boardList["b$index"] ?? {});
                              fullData.addAll(result);
                              showDialog(context: context, builder: (context) => BoardDetail(boardNum: index, data: fullData));
                            }
                          }
                        }
                      }

                      return Positioned(
                        top: finalTop, bottom: finalBottom, left: finalLeft, right: finalRight,
                        child: GameBoardTile(index: index, size: tileSize, tileData: boardList["b$index"], shouldGlow: shouldGlow, glowAnimation: _glowAnimation, itsFestival: itsFestival, onTap: handleTap),
                      );
                    }),

                    ...List.generate(4, (index) {
                      return PlayerToken(playerIndex: index, playerData: players["user${index + 1}"] ?? {}, currentTurn: currentTurn, boardSize: boardSize, tileSize: tileSize);
                    }),
                  ],
                ),
              ),
              PlayerInfoPanel(alignment: Alignment.bottomRight, playerData: players['user1'] ?? {}, color: Colors.red, name: "user1", moneyEffect: _moneyEffects["user1"], onTap: () => _showPlayerDetail("user1", Colors.red)),
              PlayerInfoPanel(alignment: Alignment.topLeft, playerData: players['user2'] ?? {}, color : Colors.blue, name : "user2", moneyEffect: _moneyEffects["user2"], onTap: () => _showPlayerDetail("user2", Colors.blue)),
              PlayerInfoPanel(alignment: Alignment.bottomLeft, playerData: players['user3'] ?? {}, color: Colors.green, name : "user3", moneyEffect: _moneyEffects["user3"], onTap: () => _showPlayerDetail("user3", Colors.green)),
              PlayerInfoPanel(alignment: Alignment.topRight, playerData: players['user4'] ?? {}, color : Colors.purple, name : "user4", moneyEffect: _moneyEffects["user4"], onTap: () => _showPlayerDetail("user4", Colors.purple)),

              // 나가기 버튼
              Positioned(
                right: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: () async {
                        bool? exit = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("게임 종료", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                            content: const Text("게임을 종료하고 메인 화면으로 돌아가시겠습니까?\n현재 진행 상황은 저장되지 않습니다."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소", style: TextStyle(color: Colors.grey))),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("종료", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            ],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            backgroundColor: const Color(0xFFFDF5E6),
                          ),
                        );
                        if (exit == true && context.mounted) {
                          context.go('/main');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF4E4BC), Color(0xFFE7D4A7)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          border: Border.all(color: const Color(0xFF8D6E63), width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                              offset: const Offset(-2, 2),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room, color: Color(0xFF5D4037), size: 24),
                            const SizedBox(height: 4),
                            const Text(
                              "나가기",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5D4037),
                              ),
                            ),
                          ],
                        ),
                      ),
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
    // 돈 포멧팅 함수
    String _formatMoney(dynamic number) {
      if (number == null) return "0";
      return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},');
    }
}