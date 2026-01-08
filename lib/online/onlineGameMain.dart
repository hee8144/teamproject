import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

// 💡 팝업 및 퀴즈 위젯 import
import '../Popup/Construction.dart';
import '../Popup/Island.dart';
import '../Popup/Takeover.dart';
import '../Popup/Bankruptcy.dart';
import '../Popup/Detail.dart';
import '../Popup/BoardDetail.dart';
import '../Popup/TaxDialog.dart';
import '../quiz/chance_card_quiz_after.dart';
import '../quiz/quiz_dialog.dart';
import '../quiz/quiz_question.dart';
import '../quiz/quiz_repository.dart';
import '../quiz/quiz_result_popup.dart';
import 'onlinedice.dart';

// ✅ WarningDialog import
import '../Popup/warning.dart';

class OnlineGamePage extends StatefulWidget {
  final String roomId;
  const OnlineGamePage({super.key, required this.roomId});

  @override
  State<OnlineGamePage> createState() => _OnlineGamePageState();
}

class _OnlineGamePageState extends State<OnlineGamePage> with TickerProviderStateMixin {
  late IO.Socket socket;
  Map<String, dynamic>? gameState;
  int myIndex = 0;
  bool isMyTurn = false;

  // 하이라이트 및 애니메이션 관련 변수
  int? _highlightOwner;
  late AnimationController _glowController;
  String eventNow = "";
  late Animation<double> _glowAnimation;
  bool _isMoving = false;

  // 더블 상태 임시 저장 변수
  bool _pendingIsDouble = false;

  // 💰 돈 변화 이펙트 상태 관리
  Map<String, String?> _moneyEffects = {};

  // ⚠️ 온라인 게임 전용 경고 기록
  final Set<String> _shownOnlineWarnings = {};

  // 액션 활성화 상태 (중복 실행 방지)
  bool isActionActive = false;

  // 주사위 제어 키
  final GlobalKey<onlineDiceAppState> diceAppKey = GlobalKey<onlineDiceAppState>();

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(_glowController);

    _initSocket();
  }

  void _initSocket() {
    // 💡 테스트 환경에 맞게 IP 주소 변경
    socket = IO.io('http://10.0.2.2:3000',
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build());

    socket.on('init_data', (data) {
      if (mounted && data != null) {
        setState(() {
          myIndex = int.tryParse(data['myIndex']?.toString() ?? '0') ?? 0;
          gameState = Map<String, dynamic>.from(data['state']);
          isMyTurn = (int.tryParse(gameState!['currentTurn']?.toString() ?? '0') == myIndex);
        });
      }
    });

    socket.on('update_state', (data) {
      if (!mounted || data == null) return;

      final newState = Map<String, dynamic>.from(data);

      if (gameState != null && gameState!['users'] != null) {
        final oldUsers = gameState!['users'] as Map<String, dynamic>;
        final newUsers = newState['users'] as Map<String, dynamic>;

        for (int i = 1; i <= 4; i++) {
          String key = 'user$i';
          if (oldUsers.containsKey(key) && newUsers.containsKey(key)) {
            int oldMoney = int.tryParse(oldUsers[key]['money']?.toString() ?? '0') ?? 0;
            int newMoney = int.tryParse(newUsers[key]['money']?.toString() ?? '0') ?? 0;
            int diff = newMoney - oldMoney;
            if (diff != 0) {
              _triggerMoneyEffect(key, diff);
            }
          }
        }
      }

      setState(() {
        if (_isMoving && gameState != null) {
          newState['users'] = gameState!['users'];
        }
        gameState = newState;
        isMyTurn = (int.tryParse(gameState!['currentTurn']?.toString() ?? '0') == myIndex);
      });
    });

    // 🏆 게임 종료 이벤트
    socket.on('game_over', (data) {
      if (!mounted) return;
      int winner = int.tryParse(data['winner']?.toString() ?? '0') ?? 0;
      String type = data['type']?.toString() ?? 'unknown';
      context.go('/onlineGameResult?roomId=${widget.roomId}&victoryType=$type&winnerIndex=$winner');
    });

    // ⚠️ 독점 경고 이벤트
    socket.on('warning_message', (data) {
      if (!mounted) return;
      List<int> players = List<int>.from(data['players'] ?? []);
      String type = data['type']?.toString() ?? 'line';

      players.sort();
      String warningKey = "$type-${players.join('_')}";

      if (_shownOnlineWarnings.contains(warningKey)) {
        return;
      }

      _shownOnlineWarnings.add(warningKey);

      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => WarningDialog(players: players, type: type),
      );
    });

    socket.on('dice_animation', (data) {
      diceAppKey.currentState?.rollDiceFromServer(data['d1'], data['d2']);
    });

    socket.on('move_player', (data) async {
      int playerIndex = data['playerIndex'];
      int steps = data['steps'];
      bool isDouble = data['isDouble'] ?? false;
      if (mounted) {
        await _animateMovement(playerIndex, steps, isDouble);
      }
    });

    socket.on('request_action', (data) {
      int requestedPlayerIndex = int.tryParse(data['playerIndex']?.toString() ?? '0') ?? 0;
      if (requestedPlayerIndex == myIndex) {
        print("✅ 내 턴 액션 실행: ${data['type']}");
        _handleServerRequest(data);
      } else {
        print("❌ 상대방(${requestedPlayerIndex}) 액션 대기 중...");
      }
    });

    socket.onConnect((_) => socket.emit('join_game', {'roomId': widget.roomId}));
    if (socket.connected) socket.emit('join_game', {'roomId': widget.roomId});
    socket.connect();
  }

  void _triggerMoneyEffect(String userKey, int amount) {
    setState(() {
      _moneyEffects[userKey] = amount > 0 ? "+$amount" : "$amount";
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _moneyEffects[userKey] = null;
        });
      }
    });
  }

  Future<void> _animateMovement(int playerIndex, int steps, bool isDouble, {bool isTravel = false}) async {
    setState(() => _isMoving = true);

    String userKey = 'user$playerIndex';
    int currentPosInUI = int.tryParse(gameState!['users'][userKey]['position']?.toString() ?? '0') ?? 0;
    int actualSteps = steps;

    if (isTravel || steps == 0) {
      int finalTargetPos = int.tryParse(gameState!['users'][userKey]['position']?.toString() ?? '0') ?? 0;
      actualSteps = (finalTargetPos - currentPosInUI + 28) % 28;
      if (actualSteps == 0) {
        setState(() => _isMoving = false);
        return;
      }
    }

    for (int i = 0; i < actualSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() {
        currentPosInUI = (currentPosInUI + 1) % 28;
        gameState!['users'][userKey]['position'] = currentPosInUI;
      });
    }

    setState(() => _isMoving = false);

    if (playerIndex == myIndex && !isTravel) {
      socket.emit('move_complete', {
        'roomId': widget.roomId,
        'playerIndex': myIndex,
        'finalPos': currentPosInUI,
        'isDouble': isDouble,
      });
    }
  }

  Future<void> _handleServerRequest(Map<String, dynamic> data) async {
    if (gameState == null) return;
    final String type = data['type']?.toString() ?? '';
    final int pos = int.tryParse(data['pos']?.toString() ?? '0') ?? 0;
    final bool isDouble = data['isDouble'] ?? false;

    if (type == 'land_event') {
      await _handleLandEvent(pos, isDouble);
    } else if (type == 'toll_event') {
      await _handleTollAndTakeover(data, isDouble);
    } else if (type == 'tax_event') {
      await _handleTaxEvent(data, isDouble);
    } else if (type == 'festival_event') {
      _handleHighlightAction("festival", isDouble);
    } else if (type == 'travel_select') {
      _handleHighlightAction("trip", false);
    } else if (type == 'start_event') {
      await _showSimpleDialog("출발지에 도착했습니다!\n원하는 내 땅을 무료로 업그레이드 하세요.");
      _handleHighlightAction("start", isDouble);
    } else if (type == 'chance') {
      await _handleChanceEvent(data, isDouble);
    } else if (type == 'island_event') {
      await _handleIslandEvent(data);
    }
  }

  // --- 0. 국세청 이벤트 ---
  Future<void> _handleTaxEvent(Map<String, dynamic> data, bool isDouble) async {
    int taxAmount = int.tryParse(data['tax']?.toString() ?? '0') ?? 0;
    int myMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;
    int totalMoney = int.tryParse(gameState!['users']['user$myIndex']['totalMoney']?.toString() ?? '0') ?? 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TaxDialog(
          user: myIndex,
          taxAmount: taxAmount,
          currentMoney: myMoney
      ),
    );

    _completeAction({
      'users': {
        'user$myIndex': {
          'money': myMoney - taxAmount,
          'totalMoney': totalMoney - taxAmount
        }
      }
    }, isDouble: isDouble);
  }

  // --- 1. 일반 땅 (건설) ---
  Future<void> _handleLandEvent(int pos, bool isDouble) async {
    if (gameState == null) {
      _completeAction({}, isDouble: isDouble);
      return;
    }

    final tile = gameState!['board']['b$pos'];
    final int owner = int.tryParse(tile['owner']?.toString() ?? '0') ?? 0;
    final int currentLevel = int.tryParse(tile['level']?.toString() ?? '0') ?? 0;
    final int myLevel = int.tryParse(gameState!['users']['user$myIndex']['level']?.toString() ?? '1') ?? 1;

    int myTotalMoney = int.tryParse(gameState!['users']['user$myIndex']['totalMoney']?.toString() ?? '0') ?? 0;

    if (owner == myIndex) {
      if (myLevel <= currentLevel) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("레벨이 부족하여 증축할 수 없습니다!"), duration: Duration(seconds: 1)));
        _completeAction({}, isDouble: isDouble);
        return;
      }
    }

    if (owner == 0 || owner == myIndex) {
      final result = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConstructionDialog(
          user: myIndex,
          buildingId: pos,
          gameState: gameState,
        ),
      );

      if (result != null && result is Map) {
        int cost = result['totalCost'] ?? 0;
        bool shouldKeepTurn = (eventNow == "trip") ? false : isDouble;
        _completeAction({
          'board': {
            'b$pos': {
              'level': result['level'],
              'owner': myIndex.toString()
            }
          },
          'users': {
            'user$myIndex': {
              'money': (int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0) - cost,
              'totalMoney': myTotalMoney,
            }
          }
        }, isDouble: shouldKeepTurn);
        if(eventNow == "trip") eventNow = "";
        return;
      }
    }

    _completeAction({}, isDouble: isDouble);
  }

  // --- 2. 통행료 및 인수 ---
  Future<void> _handleTollAndTakeover(Map<String, dynamic> data, bool isDouble) async {
    int pos = int.tryParse(data['pos']?.toString() ?? '0') ?? 0;
    int toll = int.tryParse(data['toll']?.toString() ?? '0') ?? 0;
    int ownerIdx = int.tryParse(data['ownerIndex']?.toString() ?? '0') ?? 0;
    int myMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;
    int myTotalMoney = int.tryParse(gameState!['users']['user$myIndex']['totalMoney']?.toString() ?? '0') ?? 0;

    if (ownerIdx == myIndex) {
      await _handleLandEvent(pos, isDouble);
      return;
    }

    if (myMoney < toll) {
      final bankruptResult = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BankruptDialog(lackMoney: toll - myMoney, reason: "toll", user: myIndex),
      );
      if (bankruptResult != null && bankruptResult["result"] == "BANKRUPT") {
        socket.emit('player_bankrupt', {'roomId': widget.roomId, 'playerIndex': myIndex});
        return;
      }
    }

    int remainingMoney = myMoney - toll;
    Map<String, dynamic> updateData = {
      'users': {
        'user$myIndex': {
          'money': remainingMoney,
          'totalMoney': myTotalMoney - toll
        },
        'user$ownerIdx': {
          'money': (int.tryParse(gameState!['users']['user$ownerIdx']['money']?.toString() ?? '0') ?? 0) + toll
        }
      },
      'board': {}
    };

    var tileData = gameState!['board']['b$pos'];
    int currentLevel = int.tryParse(tileData['level']?.toString() ?? '0') ?? 0;

    if (currentLevel < 4) {
      final bool? confirmTakeover = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => TakeoverDialog(
          buildingId: pos,
          user: myIndex,
          gameState: gameState,
        ),
      );

      if (confirmTakeover == true) {
        int playerLevel = int.tryParse(gameState!['users']['user$myIndex']['level']?.toString() ?? '1') ?? 1;
        int takeoverCost = (tileData['tollPrice'] ?? 0) * 2;
        int currentTotalMoneyAfterToll = myTotalMoney - toll;

        int decreasedAsset = (takeoverCost / 2).floor();
        int newTotalMoney = currentTotalMoneyAfterToll - decreasedAsset;

        updateData['users']['user$ownerIdx']['money'] = (updateData['users']['user$ownerIdx']['money'] ?? 0) + takeoverCost;

        if (playerLevel > currentLevel) {
          Map<String, dynamic> tempGameState = Map<String, dynamic>.from(gameState!);
          Map<String, dynamic> tempBoard = Map<String, dynamic>.from(tempGameState['board']);
          Map<String, dynamic> tempTile = Map<String, dynamic>.from(tempBoard['b$pos']);
          tempTile['owner'] = myIndex.toString();
          tempBoard['b$pos'] = tempTile;
          tempGameState['board'] = tempBoard;

          final buildResult = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => ConstructionDialog(
              user: myIndex,
              buildingId: pos,
              gameState: tempGameState,
            ),
          );

          if (buildResult != null && buildResult is Map) {
            updateData['board']['b$pos'] = {
              'level': buildResult['level'],
              'owner': myIndex.toString(),
            };
            int constructionCost = int.tryParse(buildResult['totalCost']?.toString() ?? '0') ?? 0;

            updateData['users']['user$myIndex'] = {
              'money': remainingMoney - takeoverCost - constructionCost,
              'totalMoney': newTotalMoney
            };
          } else {
            updateData['board']['b$pos'] = {
              'level': currentLevel,
              'owner': myIndex.toString(),
            };
            updateData['users']['user$myIndex'] = {
              'money': remainingMoney - takeoverCost,
              'totalMoney': newTotalMoney
            };
          }
        } else {
          updateData['board']['b$pos'] = {
            'level': currentLevel,
            'owner': myIndex.toString(),
          };
          updateData['users']['user$myIndex'] = {
            'money': remainingMoney - takeoverCost,
            'totalMoney': newTotalMoney
          };
        }
      }
    }
    _completeAction(updateData, isDouble: isDouble);
  }

  // --- 하이라이트 이벤트 ---
  Future<void> _handleHighlightAction(String type, bool isDouble) async {
    bool hasTarget = false;
    setState(() => isActionActive = true);

    gameState!['board'].forEach((key, val) {
      int owner = int.tryParse(val['owner']?.toString() ?? '0') ?? 0;
      int level = int.tryParse(val['level']?.toString() ?? '0') ?? 0;

      if (type == "festival" || type == "priceDown" || type == "start") {
        if (owner == myIndex) hasTarget = true;
      } else if (type == "earthquake" || type == "storm") {
        if (owner != 0 && owner != myIndex && level < 4) hasTarget = true;
      } else if (type == "trip") {
        hasTarget = true;
      }
    });

    if (!hasTarget) {
      await _showSimpleDialog(
          type == "festival" ? "선택할 내 땅이 없습니다!" :
          (type == "start" ? "건설할 내 땅이 없습니다!" : "공격할 수 있는 상대 땅(랜드마크 제외)이 없습니다!")
      );
      _completeAction({}, isDouble: isDouble);
      setState(() => isActionActive = false);
      return;
    }

    setState(() {
      eventNow = type;
      _pendingIsDouble = isDouble;
      if (type == "festival" || type == "priceDown" || type == "start") {
        _highlightOwner = myIndex;
      } else if (type == "earthquake" || type == "storm") {
        _highlightOwner = -1;
      } else if (type == "trip") {
        _highlightOwner = 99;
      }
    });

    _glowController.repeat(reverse: true);

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          Future.delayed(const Duration(seconds: 2), () {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          });
          return _showEventDialog();
        },
      );
    }
  }

  Widget _showEventDialog() {
    String eventText = "";
    int turn = int.tryParse(gameState!['currentTurn']?.toString() ?? '1') ?? 1;

    if(eventNow == "trip") eventText = "user$turn님 여행갈 땅을 선택해주세요!";
    else if(eventNow == "festival") eventText = "user$turn님 축제가 열릴 땅을 선택해주세요!";
    else if(eventNow == "start") eventText = "user$turn님 건설할 땅을 선택해주세요!";
    else if(eventNow == "storm") eventText = "user$turn님 태풍 피해를 입을 상대 땅을 선택하세요.";
    else if(eventNow == "earthquake") eventText = "user$turn님 지진을 일으킬 상대 땅을 선택하세요!";
    else if(eventNow == "priceDown") eventText = "user$turn님 통행료를 할인할 내 땅을 선택하세요!";

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC0A060), width: 4),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2))]
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 40, color: Colors.brown),
              const SizedBox(height: 10),
              Text(eventText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                  textAlign: TextAlign.center
              )
            ]
        ),
      ),
    );
  }

  Future<void> _stopHighlight(int index, String event) async {
    setState(() { _highlightOwner = null; });
    _glowController.stop();
    _glowController.reset();

    Map<String, dynamic> updateData = { 'board': {}, 'users': {} };

    if (event == "festival") {
      int oldFestivalIndex = -1;
      gameState!['board'].forEach((key, val) {
        if (val['isFestival'] == true) oldFestivalIndex = int.tryParse(key.replaceAll('b', '')) ?? -1;
      });
      if (oldFestivalIndex != -1) updateData['board']['b$oldFestivalIndex'] = {'isFestival': false};
      updateData['board']['b$index'] = {'isFestival': true};

    } else if (event == "earthquake" || event == "storm") {
      String tileKey = "b$index";
      var tileData = gameState!['board'][tileKey];
      int currentLevel = tileData['level'] ?? 0;
      String ownerNum = tileData['owner'].toString();

      int newLevel = (currentLevel > 0) ? currentLevel - 1 : 0;

      updateData['board'][tileKey] = {
        'level': newLevel,
        'owner': newLevel == 0 ? "0" : ownerNum,
        'isFestival': false
      };

      int price = (tileData['tollPrice'] ?? 0) as int;
      int ownerMoney = (gameState!['users']['user$ownerNum']['money'] ?? 0) as int;
      updateData['users']['user$ownerNum'] = {'money': ownerMoney - (price ~/ 2)};

    } else if (event == "priceDown") {
      updateData['board']['b$index'] = {'multiply': 0.5};
    } else if (event == "trip") {
      socket.emit('travel_move', {
        'roomId': widget.roomId,
        'playerIndex': myIndex,
        'targetPos': index,
      });

      _pendingIsDouble = false;
      return;

    } else if (event == "start") {
      final result = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConstructionDialog(
          user: myIndex,
          buildingId: index,
          gameState: gameState,
        ),
      );

      if (result != null && result is Map) {
        updateData['board']['b$index'] = {
          'level': result['level'],
          'owner': myIndex.toString()
        };
      } else {
        return;
      }
    }
    if (mounted) {
      setState(() => isActionActive = false);
    }
    _completeAction(updateData, isDouble: _pendingIsDouble);
    _pendingIsDouble = false;
  }

  Future<void> _handleChanceEvent(Map<String, dynamic> data, bool isDouble) async {
    if (gameState == null) return;
    setState(() => isActionActive = true);
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

    final String? actionResult = await showDialog<String>(
      useSafeArea: false,
      context: context,
      barrierDismissible: false,
      builder: (context) => ChanceCardQuizAfter(
        quizEffect: isCorrect,
        storedCard: gameState!['users']['user$myIndex']['card'] ?? "",
        userIndex: myIndex,
      ),
    );

    if (actionResult == null) {
      _completeAction({}, isDouble: isDouble);
      setState(() => isActionActive = false);
      return;
    }

    Map<String, dynamic> updateData = {'users': {'user$myIndex': {}}};
    var myUpdate = updateData['users']['user$myIndex'];
    bool nextIsDouble = isDouble;
    if (actionResult == "d_island" || actionResult == "d_rest") nextIsDouble = false;

    switch (actionResult) {
      case "c_trip":
        socket.emit('reserve_travel', {
          'roomId': widget.roomId,
          'playerIndex': myIndex,
        });
        setState(() => isActionActive = false);
        return;
      case "c_start":
        myUpdate['position'] = 0;
        socket.emit('move_complete', {
          'roomId': widget.roomId,
          'playerIndex': myIndex,
          'finalPos': 0,
          'isDouble': nextIsDouble,
        });
        setState(() => isActionActive = false);
        return;
      case "c_bonus":
        int currentMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;
        myUpdate['money'] = currentMoney + 3000000;
        setState(() => isActionActive = false);
        break;
      case "d_island":
        myUpdate['position'] = 7;
        myUpdate['islandCount'] = 3;
        setState(() => isActionActive = false);
        break;
      case "d_tax":
        myUpdate['position'] = 26;
        socket.emit('move_complete', {
          'roomId': widget.roomId,
          'playerIndex': myIndex,
          'finalPos': 26,
          'isDouble': nextIsDouble,
        });

        // 3. 여기서 함수 종료 (action_complete를 중복으로 보내지 않기 위함)
        setState(() => isActionActive = false);
        return;
      case "d_rest":
        myUpdate['restCount'] = 1;
        _completeAction(updateData, isDouble: false);
        setState(() => isActionActive = false);
        return;
      case "d_priceUp": myUpdate['isDoubleToll'] = true; break;
      case "d_move":
        int randomPos = (myIndex + (DateTime.now().millisecond % 27)) % 28;
        myUpdate['position'] = randomPos;
        setState(() => isActionActive = false);
        break;
      case "c_shield": myUpdate['card'] = "shield"; break;
      case "c_escape": myUpdate['card'] = "escape"; break;
      case "c_festival":await _handleHighlightAction("festival", nextIsDouble); setState(() => isActionActive = false);return;
      case "c_earthquake":await _handleHighlightAction("earthquake", nextIsDouble); setState(() => isActionActive = false);return;
      case "d_storm":await _handleHighlightAction("storm", nextIsDouble); setState(() => isActionActive = false);return;
      case "d_priceDown":await _handleHighlightAction("priceDown", nextIsDouble); setState(() => isActionActive = false);return;
      default: _completeAction({}, isDouble: nextIsDouble); setState(() => isActionActive = false);return;
    }
    _completeAction(updateData, isDouble: nextIsDouble);
  }

  Future<void> _handleIslandEvent(Map<String, dynamic> data) async {
    setState(() => isActionActive = true);
    final bool result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IslandDialog(user: myIndex, gameState: gameState),
    );

    if (result == true) {
      int currentMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;
      _completeAction({
        'users': {'user$myIndex': {'money': currentMoney - 1000000, 'islandCount': 0}}
      });
    } else {
      socket.emit('island_wait_complete', {'roomId': widget.roomId, 'playerIndex': myIndex});
    }
    setState(() => isActionActive = false);
  }

  void _completeAction(Map<String, dynamic> stateUpdate, {bool isDouble = false}) {
    socket.emit('action_complete', {
      'roomId': widget.roomId,
      'stateUpdate': stateUpdate,
      'isDouble': isDouble
    });
  }

  Future<void> _showSimpleDialog(String message) async {
    await showDialog(
        context: context,
        builder: (ctx) {
          Future.delayed(const Duration(seconds: 2), () => {if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context)
          }});
          return AlertDialog(content: Text(message, textAlign: TextAlign.center));
        }
    );
  }

  Offset _getTilePosition(int index, double tileSize) {
    double x = 0, y = 0;
    if (index <= 7) { x = (7 - index) * tileSize; y = 7 * tileSize; }
    else if (index <= 14) { x = 0; y = (14 - index) * tileSize; }
    else if (index <= 21) { x = (index - 14) * tileSize; y = 0; }
    else { x = 7 * tileSize; y = (index - 21) * tileSize; }
    return Offset(x, y);
  }

  // ✅ [수정됨] 3자리 쉼표 포맷팅
  String _formatMoney(dynamic number) {
    if (number == null) return "0";
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  Color _getColor(int i) {
    if (i == 1) return Colors.red;
    if (i == 2) return Colors.blue;
    if (i == 3) return Colors.green;
    return Colors.purple;
  }

  Color _getAreaColor(int i) {
    if (i >= 1 && i <= 3) return Colors.orange;
    if (i >= 4 && i <= 6) return Colors.lightGreen;
    if (i >= 8 && i <= 10) return Colors.pinkAccent;
    if (i >= 11 && i <= 13) return Colors.cyan;
    if (i >= 15 && i <= 17) return Colors.redAccent;
    if (i >= 18 && i <= 20) return Colors.yellow;
    if (i >= 22 && i <= 24) return Colors.purpleAccent;
    if (i >= 25 && i <= 27) return Colors.blueAccent;
    return Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    if (gameState == null) {
      return Scaffold(backgroundColor: Colors.grey[900], body: const Center(child: CircularProgressIndicator(color: Colors.amber)));
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
            Container(width: double.infinity, height: double.infinity,
                decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/board-background.PNG'), fit: BoxFit.cover))),

            SizedBox(
              width: boardSize, height: boardSize,
              child: Stack(
                children: [
                  if( !isActionActive && !_isMoving)
                    Center(
                      child: Container(
                        width: boardSize * 0.75, height: boardSize * 0.75,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: onlineDiceApp(
                          key: diceAppKey,
                          turn: int.tryParse(gameState!['currentTurn']?.toString() ?? '1') ?? 1,
                          totalTurn: gameState!['totalTurn'] ?? 20,
                          isBot: false,
                          onRoll: (v1, v2) => socket.emit('roll_dice', {'roomId': widget.roomId}),
                          isOnline: true,
                          isMyTurn: isMyTurn,
                        ),
                      ),
                    ),
                  ...List.generate(28, (index) => _buildGameTile(index, tileSize)),
                  ...List.generate(4, (index) => _buildAnimatedPlayer(index, tileSize)),
                ],
              ),
            ),

            _buildPlayerInfoPanel(Alignment.bottomRight, gameState!['users']['user1'], Colors.red, "Player 1"),
            _buildPlayerInfoPanel(Alignment.topLeft, gameState!['users']['user2'], Colors.blue, "Player 2"),
            _buildPlayerInfoPanel(Alignment.bottomLeft, gameState!['users']['user3'], Colors.green, "Player 3"),
            _buildPlayerInfoPanel(Alignment.topRight, gameState!['users']['user4'], Colors.purple, "Player 4"),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfoPanel(Alignment alignment, Map<String, dynamic> playerData, Color color, String name) {
    int myRank = 1;
    num myTotal = num.tryParse(playerData['totalMoney']?.toString() ?? '0') ?? 0;

    String myKey = "";
    if (gameState != null && gameState!['users'] != null) {
      final users = gameState!['users'] as Map<String, dynamic>;

      users.forEach((k, v) {
        if (v['name'] == name) myKey = k;
      });
      if (myKey.isEmpty && name.toLowerCase().startsWith("player")) {
        myKey = "user${name.split(' ')[1]}";
      }

      users.forEach((key, val) {
        if (key != myKey && val['type'] != 'N') {
          num otherTotal = num.tryParse(val['totalMoney']?.toString() ?? '0') ?? 0;
          if (otherTotal > myTotal) myRank++;
        }
      });
    }

    Map<String, dynamic> finalData = Map.from(playerData);
    finalData['rank'] = myRank;

    String displayName = playerData['name']?.toString() ?? name;
    String? currentEffect = _moneyEffects[myKey];

    return OnlinePlayerInfoPanel(
      alignment: alignment,
      playerData: finalData,
      color: color,
      name: displayName,
      moneyEffect: currentEffect,
      onTap: () { },
    );
  }

  // ✅ [수정됨] 특수 타일 등 처리: 첫 공백 앞 단어 제거
  Widget _buildGameTile(int index, double tileSize) {
    final pos = _getTilePosition(index, tileSize);
    final tileData = gameState!['board']['b$index'] ?? {};
    final String type = tileData['type'] ?? 'land';

    // 💡 1. 이름 처리 로직 (첫 공백 앞 단어 제거)
    String originalName = tileData['name']?.toString() ?? "";
    String displayName = originalName;
    int firstSpaceIndex = originalName.indexOf(' ');

    if (firstSpaceIndex != -1) {
      displayName = originalName.substring(firstSpaceIndex + 1);
    }

    bool isHighlighted = false;
    if (_highlightOwner != null) {
      if (_highlightOwner == 99) isHighlighted = true;
    }

    return Positioned(
      left: pos.dx, top: pos.dy,
      child: GestureDetector(
        onTap: () async {
          if (_highlightOwner == 99) {
            await _stopHighlight(index, eventNow);
          }
        },
        child: Container(
          width: tileSize, height: tileSize,
          padding: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 0.5)
          ),
          child: Stack(
            children: [
              type == 'land'
                  ? _buildLandContent(tileData, index)
                  : Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                      displayName, // 💡 수정된 이름 사용
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
              if (isHighlighted && type != 'land')
                FadeTransition(
                  opacity: _glowAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.yellowAccent, width: 3),
                      color: Colors.yellowAccent.withOpacity(0.3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ [수정됨] 일반 땅 처리: 첫 공백 앞 단어 제거
  Widget _buildLandContent(Map<String, dynamic> tileData, int index) {
    final int buildLevel = int.tryParse(tileData['level']?.toString() ?? '0') ?? 0;
    final int owner = int.tryParse(tileData['owner']?.toString() ?? '0') ?? 0;
    final bool isFestival = tileData['isFestival'] ?? false;

    // 💡 1. 이름 처리 로직 (첫 공백 앞 단어 제거)
    String originalName = tileData["name"]?.toString() ?? "";
    String displayName = originalName;
    int firstSpaceIndex = originalName.indexOf(' ');

    if (firstSpaceIndex != -1) {
      displayName = originalName.substring(firstSpaceIndex + 1);
    }

    // --- 통행료 계산 ---
    int currentToll = 0;
    if (buildLevel > 0 && owner != 0) {
      int basePrice = int.tryParse(tileData["tollPrice"]?.toString() ?? "0") ?? 0;
      int levelMult = 0;
      switch (buildLevel) {
        case 1: levelMult = 2; break;
        case 2: levelMult = 6; break;
        case 3: levelMult = 14; break;
        case 4: levelMult = 30; break;
      }
      double multiply = double.tryParse(tileData["multiply"]?.toString() ?? "1.0") ?? 1.0;
      if (isFestival && multiply == 1.0) multiply *= 2;
      currentToll = (basePrice * levelMult * multiply).round();
    }
    // ----------------

    bool isHighlighted = false;
    if (_highlightOwner != null) {
      if (_highlightOwner == 99) {
        isHighlighted = true;
      } else if (_highlightOwner == myIndex && owner == myIndex) {
        isHighlighted = true;
      } else if (_highlightOwner == -1 && owner != 0 && owner != myIndex) {
        if (buildLevel < 4) isHighlighted = true;
      }
    }
    bool isFestivalLocation = tileData['isFestival'] == true;
    double multiply = (tileData["multiply"] as num? ?? 1.0).toDouble();
    if (isFestivalLocation && multiply == 1.0) multiply *= 2;

    return GestureDetector(
      onTap: () async {
        if (_highlightOwner != null) {
          if (_highlightOwner == 99) {
            await _stopHighlight(index, eventNow);
            return;
          } else if (owner == _highlightOwner) {
            await _stopHighlight(index, eventNow);
            return;
          } else if (_highlightOwner == -1 && owner != 0 && owner != myIndex) {
            if (buildLevel < 4) {
              await _stopHighlight(index, eventNow);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("랜드마크는 공격할 수 없습니다!"), duration: Duration(seconds: 1)),
              );
            }
            return;
          }
          return;
        }

        if (tileData != null && tileData["type"] == "land") {
          final result = await showDialog(
              context: context,
              builder: (context) {
                return DetailPopup(boardNum: index, onNext: (){}, roomId: widget.roomId);
              }
          );
          if (result != null) {
            Map<String, dynamic> fullData = Map<String, dynamic>.from(tileData ?? {});
            fullData.addAll(result);
            showDialog(context: context, builder: (context) => BoardDetail(boardNum: index, data: fullData, roomId: widget.roomId));
          }
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 3.0),
                  color: _getAreaColor(index),
                  child: (multiply > 1)
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
                      if(isFestivalLocation)
                        const Opacity(opacity: 0.5, child: Icon(Icons.celebration, size: 24, color: Colors.purple)),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Text(
                              displayName, // 💡 수정된 이름 사용
                              style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(_formatMoney(currentToll), style: TextStyle(fontSize: 5, color: Colors.grey[700])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isFestival)
            const Positioned(top: 2, left: 2, child: Icon(Icons.celebration, size: 12, color: Colors.orange)),
          if (buildLevel > 0 && owner > 0)
            Positioned(
              top: 0, right: 0,
              child: ClipPath(
                clipper: _TopRightTriangleClipper(),
                child: Container(
                  width: 32, height: 32,
                  color: _getColor(owner),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(top: 2, right: 3),
                  child: buildLevel < 4
                      ? Text("$buildLevel", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))
                      : const Icon(Icons.star, size: 9, color: Colors.white),
                ),
              ),
            ),
          if (isHighlighted)
            FadeTransition(
              opacity: _glowAnimation,
              child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.yellowAccent, width: 4), color: Colors.yellowAccent.withOpacity(0.3))),
            ),
          if (_highlightOwner != null)
            AnimatedBuilder(
                animation: _glowAnimation,
                builder: (ctx, child) {
                  bool showGlow = false;
                  if (_highlightOwner == myIndex && owner == myIndex) showGlow = true;
                  if (_highlightOwner == -1 && owner != 0 && owner != myIndex) showGlow = true;
                  if (!showGlow) return const SizedBox();
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber.withOpacity(_glowAnimation.value), width: 3),
                    ),
                  );
                }
            )
        ],
      ),
    );
  }

  Widget _buildAnimatedPlayer(int playerIdx, double tileSize) {
    final user = gameState!['users']['user${playerIdx + 1}'];
    if (user == null || user['type'] == 'D' || user['type'] == 'N') return const SizedBox();

    final int position = int.tryParse(user['position']?.toString() ?? '0') ?? 0;
    final tilePos = _getTilePosition(position, tileSize);
    final double tokenSize = tileSize * 0.5;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
      left: tilePos.dx + (tileSize - tokenSize) / 2,
      top: tilePos.dy + (tileSize - tokenSize) / 2,
      child: Container(
        width: tokenSize, height: tokenSize,
        decoration: BoxDecoration(
          color: _getColor(playerIdx + 1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Center(child: Text("${playerIdx + 1}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    socket.dispose();
    super.dispose();
  }
}

class _TopRightTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width * 0.3, 0);
    path.lineTo(size.width, size.height * 0.7);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class OnlinePlayerInfoPanel extends StatelessWidget {
  final Alignment alignment;
  final Map<String, dynamic> playerData;
  final Color color;
  final String name;
  final String? moneyEffect;
  final VoidCallback? onTap;

  const OnlinePlayerInfoPanel({
    super.key,
    required this.alignment,
    required this.playerData,
    required this.color,
    required this.name,
    this.moneyEffect,
    this.onTap,
  });

  String _formatMoney(dynamic number) {
    if (number == null) return "0";
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    String type = playerData['type'] ?? "N";
    if (type == "N") return const SizedBox();

    bool isBankrupt = (type == "D");

    String displayName = name;
    if (isBankrupt) displayName = "파산";

    bool isTop = alignment.y < 0;
    bool isLeft = alignment.x < 0;

    String money = _formatMoney(playerData['money']);
    String totalMoney = _formatMoney(playerData['totalMoney']);

    int rank = playerData['rank'] ?? 0;
    bool isDoubleToll = playerData['isDoubleToll'] ?? false;
    String card = playerData['card'] ?? "";

    double? effectTopPos = isTop ? 90 : -45;

    IconData? cardIcon;
    Color cardColor = Colors.transparent;
    if (card == "shield") {
      cardIcon = Icons.shield;
      cardColor = Colors.blueAccent;
    } else if (card == "escape") {
      cardIcon = Icons.vpn_key;
      cardColor = Colors.orangeAccent;
    }

    var panelBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomLeft: isLeft ? const Radius.circular(5) : const Radius.circular(15),
      bottomRight: isLeft ? const Radius.circular(15) : const Radius.circular(5),
    );

    return Positioned(
      top: isTop ? 20 : null,
      bottom: isTop ? null : 20,
      left: isLeft ? 10 : null,
      right: isLeft ? null : 10,
      child: SizedBox(
        width: 170,
        height: 85,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (cardIcon != null && !isBankrupt)
              Positioned(
                top: isTop ? null : -12,
                bottom: isTop ? -22 : null,
                left: isLeft ? 10 : null,
                right: isLeft ? null : 10,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2))],
                  ),
                  child: Icon(cardIcon, size: 18, color: Colors.white),
                ),
              ),

            Positioned(
              top: 10, bottom: 0,
              left: isLeft ? 0 : 25,
              right: isLeft ? 25 : 0,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isBankrupt
                          ? [Colors.grey.shade800, Colors.black]
                          : [color.withOpacity(0.9), color.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: panelBorderRadius,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                    border: Border.all(
                        color: isBankrupt ? Colors.grey.withOpacity(0.3) : Colors.white.withOpacity(0.6), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isLeft && isDoubleToll) const SizedBox(width: 1),
                          if (!isLeft && isDoubleToll) _buildDoubleBadge(),
                          if (!isLeft && !isDoubleToll) const SizedBox(width: 1),

                          Text(
                            displayName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isBankrupt ? Colors.grey.shade600 : Colors.white,
                                fontSize: 12),
                          ),

                          if (isLeft && isDoubleToll) _buildDoubleBadge(),
                          if (isLeft && isDoubleToll) const SizedBox(width: 1)
                        ],
                      ),
                      const SizedBox(height: 4),
                      _moneyText("현금", money, isLeft),
                      _moneyText("자산", totalMoney, isLeft),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 0,
              left: isLeft ? 125 : 0,
              child: Container(
                width: 45, height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isBankrupt ? Colors.grey.shade400 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isBankrupt ? Colors.grey.shade600 : color, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("RANK", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text("$rank", style: TextStyle(fontSize: 18, color: isBankrupt ? Colors.grey.shade600 : color, fontWeight: FontWeight.w900, height: 1.0)),
                  ],
                ),
              ),
            ),

            if (moneyEffect != null && !isBankrupt)
              Positioned(
                top: effectTopPos,
                left: 0, right: 0,
                child: Center(
                  child: Stack(
                    children: [
                      Text(
                        moneyEffect!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 4
                            ..color = Colors.black,
                        ),
                      ),
                      Text(
                        moneyEffect!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: moneyEffect!.startsWith("-")
                              ? const Color(0xFFFF5252)
                              : const Color(0xFF69F0AE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (isBankrupt)
              Positioned(
                top: 10, bottom: 0,
                left: isLeft ? 0 : 25,
                right: isLeft ? 25 : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: panelBorderRadius,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _moneyText(String label, String value, bool isLeftPanel) {
    return Row(
      mainAxisAlignment: isLeftPanel ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isLeftPanel) ...[
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
        if (isLeftPanel) ...[
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
        ],
      ],
    );
  }

  Widget _buildDoubleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: const Text("x2", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w900, height: 1.0)),
    );
  }
}
