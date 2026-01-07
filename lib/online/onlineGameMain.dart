import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

// 💡 기존에 사용하시던 팝업 및 퀴즈 위젯 경로에 맞춰주세요.
import '../Popup/Construction.dart';
import '../Popup/Island.dart';
import '../Popup/Takeover.dart';
import '../Popup/Bankruptcy.dart';
import '../Popup/Detail.dart';
import '../Popup/BoardDetail.dart';
import '../Popup/TaxDialog.dart'; // 수정된 TaxDialog
import '../quiz/chance_card_quiz_after.dart';
import '../quiz/quiz_dialog.dart';
import '../quiz/quiz_question.dart';
import '../quiz/quiz_repository.dart';
import '../quiz/quiz_result_popup.dart';
import 'onlinedice.dart';

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

  // 하이라이트 관련 변수
  int? _highlightOwner;
  late AnimationController _glowController;
  String eventNow = "";
  late Animation<double> _glowAnimation;

  // ✅ [추가] 하이라이트 이벤트 중 더블 여부를 임시 저장할 변수
  bool _pendingIsDouble = false;

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
    // 💡 테스트 환경에 맞게 IP 주소 변경 (에뮬레이터: 10.0.2.2, 실기기: PC IP)
    socket = IO.io('http://localhost:3000',
    // socket = IO.io('http://10.0.2.2:3000',
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
      if (mounted && data != null) {
        setState(() {
          gameState = Map<String, dynamic>.from(data);
          isMyTurn = (int.tryParse(gameState!['currentTurn']?.toString() ?? '0') == myIndex);
        });
      }
    });

    socket.on('dice_animation', (data) {
      diceAppKey.currentState?.rollDiceFromServer(data['d1'], data['d2']);
    });

    socket.on('request_action', (data) {
      int requestedPlayerIndex = int.tryParse(data['playerIndex']?.toString() ?? '0') ?? 0;

      if (requestedPlayerIndex == myIndex) {
        print("✅ 내 턴 액션 실행: ${data['type']}");
        _handleServerRequest(data);
      } else {
        print("❌ 다른 플레이어(${requestedPlayerIndex})의 액션 기다리는 중...");
      }
    });

    socket.onConnect((_) => socket.emit('join_game', {'roomId': widget.roomId}));
    if (socket.connected) socket.emit('join_game', {'roomId': widget.roomId});
    socket.connect();
  }

  // ================= 액션 처리 로직 =================

  Future<void> _handleServerRequest(Map<String, dynamic> data) async {
    final int pos = int.tryParse(data['pos']?.toString() ?? '0') ?? 0;

    // 🔥 서버에서 보낸 더블 여부 수신
    final bool isDouble = data['isDouble'] ?? false;

    if (gameState == null) return;

    print("DEBUG: _handleServerRequest - 위치: $pos, 타입: ${data['type']}, 더블: $isDouble");

    if (data['type'] == 'land_event') {
      await _handleLandEvent(pos, isDouble);
    } else if (data['type'] == 'toll_event') {
      await _handleTollAndTakeover(data, isDouble);
    } else if (data['type'] == 'island_event') {
      await _handleIslandEvent(data); // 무인도는 더블 로직이 내부적으로 처리됨
    } else if (data['type'] == "chance") {
      await _handleChanceEvent(data, isDouble);
    } else if (data['type'] == "tax_event") {
      await _handleTaxEvent(data, isDouble);
    } else {
      _completeAction({}, isDouble: isDouble);
    }
  }

  // --- 1. 일반 땅 (건설) ---
  Future<void> _handleLandEvent(int pos, bool isDouble) async {
    if (gameState == null) {
      _completeAction({}, isDouble: isDouble);
      return;
    }

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
      _completeAction({
        'board': {
          'b$pos': {
            'level': result['level'],
            'owner': myIndex.toString()
          }
        },
        'users': {
          'user$myIndex': {
            'money': (int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0) - result['totalCost'],
          }
        }
      }, isDouble: isDouble); // 🔥 isDouble 전달
    } else {
      _completeAction({}, isDouble: isDouble); // 🔥 isDouble 전달
    }
  }

  // --- 2. 통행료 및 인수 ---
  Future<void> _handleTollAndTakeover(Map<String, dynamic> data, bool isDouble) async {
    int pos = int.tryParse(data['pos']?.toString() ?? '0') ?? 0;
    int toll = int.tryParse(data['toll']?.toString() ?? '0') ?? 0;
    int ownerIdx = int.tryParse(data['ownerIndex']?.toString() ?? '0') ?? 0;
    int myMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;

    // 내 땅이면 건설창으로 이동
    if (ownerIdx == myIndex) {
      await _handleLandEvent(pos, isDouble);
      return;
    }

    // 통행료 지불 및 파산 체크
    if (myMoney < toll) {
      final bankruptResult = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BankruptDialog(lackMoney: toll - myMoney, reason: "toll", user: myIndex),
      );
      if (bankruptResult != null && bankruptResult["result"] == "BANKRUPT") {
        socket.emit('player_bankrupt', { 'roomId': widget.roomId, 'playerIndex': myIndex });
        return;
      }
    }

    int remainingMoney = myMoney - toll;

    Map<String, dynamic> updateData = {
      'users': {
        'user$myIndex': { 'money': remainingMoney },
        'user$ownerIdx': { 'money': (int.tryParse(gameState!['users']['user$ownerIdx']['money']?.toString() ?? '0') ?? 0) + toll }
      }
    };

    // 인수 처리
    int currentLevel = int.tryParse(gameState!['board']['b$pos']['level']?.toString() ?? '0') ?? 0;

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
        // 임시 데이터 생성 (내 땅인 것처럼 속이기 위해 Deep Copy)
        Map<String, dynamic> tempGameState = Map<String, dynamic>.from(gameState!);
        Map<String, dynamic> tempBoard = Map<String, dynamic>.from(tempGameState['board'] ?? {});
        Map<String, dynamic> tempTile = Map<String, dynamic>.from(tempBoard['b$pos'] ?? {});

        tempTile['owner'] = myIndex.toString();
        tempBoard['b$pos'] = tempTile;
        tempGameState['board'] = tempBoard;

        updateData['board'] ??= {};
        updateData['board']['b$pos'] = {
          'owner': myIndex.toString(),
          'level': currentLevel
        };

        // 레벨 체크 후 건설창 호출
        int playerLevel = int.tryParse(gameState!['users']['user$myIndex']['level']?.toString() ?? '1') ?? 1;

        if (playerLevel > currentLevel) {
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
            updateData['board']['b$pos']['level'] = buildResult['level'];
            int constructionCost = int.tryParse(buildResult['totalCost']?.toString() ?? '0') ?? 0;
            updateData['users']['user$myIndex']['money'] -= constructionCost;
          }
        }
      }
    }

    _completeAction(updateData, isDouble: isDouble); // 🔥 isDouble 전달
  }

  // --- 3. 무인도 ---
  Future<void> _handleIslandEvent(Map<String, dynamic> data) async {
    final bool result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IslandDialog(
        user: myIndex,
        gameState: gameState,
      ),
    );

    if (result == true) {
      // 100만원 지불하고 즉시 탈출
      int currentMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;
      _completeAction({
        'users': {
          'user$myIndex': {
            'money': currentMoney - 1000000,
            'islandCount': 0,
          }
        }
      }, isDouble: false); // 탈출 후 주사위를 굴리게 할지 여부는 서버 로직에 따름 (보통 false)
    } else {
      // 주사위 대기
      socket.emit('island_wait_complete', {
        'roomId': widget.roomId,
        'playerIndex': myIndex
      });
    }
  }

  // --- 4. 국세청 ---
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
        'user$myIndex': { 'money': myMoney - taxAmount },
        'user$myIndex': { 'totalMoney' : totalMoney - taxAmount }
      }
    }, isDouble: isDouble); // 🔥 isDouble 전달
  }

  // --- 5. 찬스 카드 ---
  Future<void> _handleChanceEvent(Map<String, dynamic> data, bool isDouble) async {
    if (gameState == null) return;

    // 퀴즈 팝업
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

    // 찬스 카드 결과 팝업
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
      return;
    }

    Map<String, dynamic> updateData = {'users': {'user$myIndex': {}}};
    var myUpdate = updateData['users']['user$myIndex'];

    // 🚨 무인도 이동이나 휴식 시 더블 효과 소멸
    bool nextIsDouble = isDouble;
    if (actionResult == "d_island" || actionResult == "d_rest") {
      nextIsDouble = false;
    }

    switch (actionResult) {
      case "c_trip":
        myUpdate['position'] = 21;
        break;
      case "c_start":
        myUpdate['position'] = 0;
        break;
      case "c_bonus":
        int currentMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;
        myUpdate['money'] = currentMoney + 3000000;
        break;
      case "d_island":
        myUpdate['position'] = 7;
        myUpdate['islandCount'] = 3;
        break;
      case "d_tax":
        myUpdate['position'] = 26;
        break;
      case "d_rest":
        myUpdate['restCount'] = 1;
        break;
      case "d_priceUp":
        myUpdate['isDoubleToll'] = true;
        break;
      case "d_move":
        int randomPos = (myIndex + (DateTime.now().millisecond % 27)) % 28;
        myUpdate['position'] = randomPos;
        break;
      case "c_shield":
        myUpdate['card'] = "shield";
        break;
      case "c_escape":
        myUpdate['card'] = "escape";
        break;

    // 💡 하이라이트 액션 호출 (여기서 nextIsDouble 전달)
      case "c_festival":
        _handleHighlightAction("festival", nextIsDouble);
        return;
      case "c_earthquake":
        _handleHighlightAction("earthquake", nextIsDouble);
        return;
      case "d_storm":
        _handleHighlightAction("storm", nextIsDouble);
        return;
      case "d_priceDown":
        _handleHighlightAction("priceDown", nextIsDouble);
        return;

      default:
        _completeAction({}, isDouble: nextIsDouble);
        return;
    }

    _completeAction(updateData, isDouble: nextIsDouble); // 🔥 isDouble 전달
  }

  // --- 하이라이트 액션 (축제, 지진 등) ---
  void _handleHighlightAction(String type, bool isDouble) async {
    bool hasTarget = false;

    // 타겟 체크
    gameState!['board'].forEach((key, val) {
      int owner = int.tryParse(val['owner'].toString()) ?? 0;
      if (type == "festival") {
        if (owner == myIndex) hasTarget = true;
      } else { // 공격 계열
        if (owner != 0 && owner != myIndex) hasTarget = true;
      }
    });

    if (!hasTarget) {
      await _showSimpleDialog(type == "festival" ? "축제를 열 땅이 없습니다!" : "공격할 대상이 없습니다!");
      _completeAction({}, isDouble: isDouble);
      return;
    }

    setState(() {
      eventNow = type;
      _highlightOwner = (type == "festival") ? myIndex : -1;
      _pendingIsDouble = isDouble; // ✅ [핵심] 더블 여부를 임시 저장
    });

    _glowController.repeat(reverse: true);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == "festival" ? "축제를 열 내 땅을 선택하세요!" : "효과를 적용할 상대 땅을 선택하세요!"))
    );
  }

  // --- 하이라이트 종료 (땅 선택 시 호출됨) ---
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

      if (oldFestivalIndex != -1) {
        updateData['board']['b$oldFestivalIndex'] = {'isFestival': false};
      }
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
    }

    // 🔥 저장해뒀던 더블 여부를 실어서 보냄
    _completeAction(updateData, isDouble: _pendingIsDouble);
    _pendingIsDouble = false;
  }

  void _completeAction(Map<String, dynamic> stateUpdate, {bool isDouble = false}) {
    socket.emit('action_complete', {
      'roomId': widget.roomId,
      'stateUpdate': stateUpdate,
      'isDouble': isDouble // 🔥 서버로 더블 여부 전송
    });
  }

  // ... (기타 헬퍼 함수들: _showSimpleDialog, _getTilePosition, _formatMoney, _getColor, _getAreaColor) ...
  Future<void> _showSimpleDialog(String message) async {
    await showDialog(
        context: context,
        builder: (ctx) {
          Future.delayed(const Duration(seconds: 2), () => Navigator.pop(ctx));
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

  String _formatMoney(dynamic amount) {
    if (amount == null) return "0원";
    int val = int.tryParse(amount.toString()) ?? 0;
    if (val >= 10000) return "${val ~/ 10000}만";
    return "$val원";
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

            // 플레이어 패널 (동일)
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
    if (playerData['type'] == "N") return const SizedBox();
    bool isTurn = int.tryParse(gameState!['currentTurn']?.toString() ?? '0') == int.parse(name.split(' ')[1]);

    return Positioned(
      top: alignment.y < 0 ? 0 : null, bottom: alignment.y > 0 ? 0 : null,
      left: alignment.x < 0 ? 0 : null, right: alignment.x > 0 ? 0 : null,
      child: SafeArea(
        child: Container(
          width: 140, height: 70, margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(isTurn ? 1.0 : 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isTurn ? Colors.white : Colors.white54, width: isTurn ? 3 : 1),
            boxShadow: [if (isTurn) BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
              Text("자산: ${_formatMoney(playerData['money'])}", style: const TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTile(int index, double tileSize) {
    final pos = _getTilePosition(index, tileSize);
    final tileData = gameState!['board']['b$index'] ?? {};
    final String type = tileData['type'] ?? 'land';

    return Positioned(
      left: pos.dx, top: pos.dy,
      child: Container(
        width: tileSize, height: tileSize,
        padding: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300, width: 0.5)),
        child: type == 'land'
            ? _buildLandContent(tileData, index)
            : GestureDetector(
          onTap: () async {
            // 특수 타일 눌렀을 때도 상세 보기 등을 할 수 있게 처리 가능
            // 여기서는 일단 비워둠
          },
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                  tileData['name'] ?? "",
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandContent(Map<String, dynamic> tileData, int index) {
    final int buildLevel = int.tryParse(tileData['level']?.toString() ?? '0') ?? 0;
    final int owner = int.tryParse(tileData['owner']?.toString() ?? '0') ?? 0;
    bool isFestivalLocation = tileData['isFestival'] == true;
    double multiply = (tileData["multiply"] as num? ?? 1.0).toDouble();
    if (isFestivalLocation && multiply == 1.0) multiply *= 2;

    return GestureDetector(
      onTap: () async {
        // 하이라이트 이벤트 중(지진, 축제 선택)이면 해당 로직 실행
        if (_highlightOwner != null && _highlightOwner != -1) {
          // 내 땅 선택 (축제)
          if (owner == _highlightOwner) {
            await _stopHighlight(index, eventNow);
          }
          return;
        } else if (_highlightOwner == -1) {
          // 남의 땅 선택 (공격)
          if (owner != 0 && owner != myIndex) {
            await _stopHighlight(index, eventNow);
          }
          return;
        }

        // 일반적인 상세보기 팝업
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
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tileData["name"] ?? "토지",
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Text(_formatMoney(tileData["tollPrice"] ?? 0), style: TextStyle(fontSize: 6, color: Colors.grey[700])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

          // ✨ 하이라이트 효과 (Glow Animation)
          if (_highlightOwner != null)
            AnimatedBuilder(
                animation: _glowAnimation,
                builder: (ctx, child) {
                  bool showGlow = false;
                  if (_highlightOwner == myIndex && owner == myIndex) showGlow = true; // 내 땅 (축제)
                  if (_highlightOwner == -1 && owner != 0 && owner != myIndex) showGlow = true; // 남의 땅 (공격)

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
    // ... (기존과 동일)
    final user = gameState!['users']['user${playerIdx + 1}'];
    if (user == null || user['type'] == 'D') return const SizedBox();

    final int position = int.tryParse(user['position']?.toString() ?? '0') ?? 0;
    final tilePos = _getTilePosition(position, tileSize);
    final double tokenSize = tileSize * 0.5;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
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