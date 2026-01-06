import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

import '../Popup/Construction.dart';
import '../Popup/Island.dart';
import '../Popup/Takeover.dart';
import '../Popup/Bankruptcy.dart';
import '../Popup/Detail.dart';
import '../Popup/BoardDetail.dart';
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
  int? _highlightOwner;
  late AnimationController _glowController;
  String eventNow = ""; // 현재 진행 중인 하이라이트 이벤트 종류
  int _eventPlayer = 0; // 이벤트를 발생시킨 플레이어 번호
  late Animation<double> _glowAnimation;
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
    socket = IO.io('http://localhost:3000 ',
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
      // 1. 숫자로 확실하게 변환
      int requestedPlayerIndex = int.tryParse(data['playerIndex']?.toString() ?? '0') ?? 0;

      // 2. 현재 내 인덱스와 일치하는지 확인 (이 시점에 currentTurn이 바뀌어있으면 안 됨)
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

  // OnlineGamePage.dart 내부 주요 수정 로직

  Future<void> _handleServerRequest(Map<String, dynamic> data) async {
    final int pos = int.tryParse(data['pos']?.toString() ?? '0') ?? 0;
    if (gameState == null) return;

    // 1번 플레이어 외에 안 뜨는 현상 방지를 위해 로그 확인
    print("DEBUG: _handleServerRequest 실행중 - 위치: $pos, 타입: ${data['type']}");

    if (data['type'] == 'land_event') {
      await _handleLandEvent(pos);
    } else if (data['type'] == 'toll_event') {
      await _handleTollAndTakeover(data);
    }else if (data['type' ] == 'island_event') {
      await _handleIslandEvent(data);
    }else if (data['type'] == "chance") {
      // 💡 찬스 카드 이벤트 발송
      await _handleChanceEvent(data);
    }
    else {
      _completeAction({});
    }
  }

  void _handleHighlightAction(String type) async {
    bool hasTarget = false;

    // 1. 타겟이 있는지 사전 체크
    gameState!['board'].forEach((key, val) {
      int owner = int.tryParse(val['owner'].toString()) ?? 0;
      if (type == "festival") {
        if (owner == myIndex) hasTarget = true;
      } else { // 지진, 태풍, 가격하락
        if (owner != 0 && owner != myIndex) hasTarget = true;
      }
    });

    if (!hasTarget) {
      // 타겟이 없으면 안내 팝업 후 종료
      await _showSimpleDialog(type == "festival" ? "축제를 열 땅이 없습니다!" : "공격할 대상이 없습니다!");
      _completeAction({});
      return;
    }

    // 2. 하이라이트 모드 활성화 (보드가 반짝거리게 됨)
    setState(() {
      eventNow = type;
      _highlightOwner = (type == "festival") ? myIndex : -1; // -1은 내 땅 제외 모두
    });

    _glowController.repeat(reverse: true);

    // 사용자에게 안내 메시지 (Snackback 혹은 Overlay)
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == "festival" ? "축제를 열 내 땅을 선택하세요!" : "효과를 적용할 상대 땅을 선택하세요!"))
    );
  }

  Future<void> _showSimpleDialog(String message) async {
    await showDialog(
        context: context,
        builder: (ctx) {
          Future.delayed(const Duration(seconds: 2), () => Navigator.pop(ctx));
          return AlertDialog(content: Text(message, textAlign: TextAlign.center));
        }
    );
  }

  Future<void> _handleChanceEvent(Map<String, dynamic> data) async {
    if (gameState == null) return;

    // 1. 퀴즈 로직 (로컬 코드 이식)
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

    // 2. 찬스 카드 결과 팝업 (isCorrect에 따라 좋은카드/나쁜카드 결정)
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
      _completeAction({});
      return;
    }

    // 3. 결과에 따른 서버 업데이트 데이터 구성
    Map<String, dynamic> updateData = {'users': {'user$myIndex': {}}};
    var myUpdate = updateData['users']['user$myIndex'];

    switch (actionResult) {
      case "c_trip": // 국내여행
        myUpdate['position'] = 21;
        break;
      case "c_start": // 출발지
        myUpdate['position'] = 0;
        break;
      case "c_bonus": // 보너스 300만
        int currentMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;
        myUpdate['money'] = currentMoney + 3000000;
        break;
      case "d_island": // 무인도
        myUpdate['position'] = 7;
        myUpdate['islandCount'] = 3;
        break;
      case "d_tax": // 국세청
        myUpdate['position'] = 26;
        break;
      case "d_rest": // 한 턴 쉬기
        myUpdate['restCount'] = 1;
        break;
      case "d_priceUp": // 통행료 2배
        myUpdate['isDoubleToll'] = true;
        break;
      case "d_move": // 랜덤 이동
        int randomPos = (myIndex + (DateTime.now().millisecond % 27)) % 28;
        myUpdate['position'] = randomPos;
        break;
      case "c_shield":
        myUpdate['card'] = "shield";
        break;
      case "c_escape":
        myUpdate['card'] = "escape";
        break;
    // 💡 하이라이트 액션 (지진, 태풍 등)
      case "c_festival":
        _handleHighlightAction("festival");
        return;
      case "c_earthquake":
        _handleHighlightAction("earthquake");
        return;
      case "d_storm":
        _handleHighlightAction("storm");
        return;
      case "d_priceDown":
        _handleHighlightAction("priceDown");
        return;

      default:
        _completeAction({});
        return;
    }

    // 4. 서버로 최종 전송
    _completeAction(updateData);
  }

  Future<void> _stopHighlight(int index, String event) async {
    setState(() { _highlightOwner = null; });
    _glowController.stop();
    _glowController.reset();

    // 서버로 보낼 전체 데이터 객체
    Map<String, dynamic> updateData = {
      'board': {},
      'users': {}
    };

    if (event == "festival") {
      // 이전 축제 정보 제거 (기존에 축제가 있었다면)
      int oldFestivalIndex = -1;
      gameState!['board'].forEach((key, val) {
        if (val['isFestival'] == true) oldFestivalIndex = int.tryParse(key.replaceAll('b', '')) ?? -1;
      });

      if (oldFestivalIndex != -1) {
        updateData['board']['b$oldFestivalIndex'] = {'isFestival': false};
      }
      // 새로운 땅에 축제 설정
      updateData['board']['b$index'] = {'isFestival': true};

    } else if (event == "trip") {
      // 여행 이동은 단순히 위치만 변경 (서버가 위치 변경을 감지함)
      updateData['users']['user$myIndex'] = {'position': index};

    } else if (event == "earthquake" || event == "storm") {
      // 지진/태풍: 타겟 땅의 레벨을 깎고 소유주의 돈을 차감
      String tileKey = "b$index";
      var tileData = gameState!['board'][tileKey];
      int currentLevel = tileData['level'] ?? 0;
      String ownerNum = tileData['owner'].toString(); // 예: "1"

      // 💡 새로운 레벨 계산 (로컬 로직 이식)
      int newLevel = (currentLevel > 0) ? currentLevel - 1 : 0;

      updateData['board'][tileKey] = {
        'level': newLevel,
        'owner': newLevel == 0 ? "0" : ownerNum, // 레벨 0이면 소유주 없음
        'isFestival': false
      };

      // 소유주 돈 차감 (필요 시)
      int price = (tileData['tollPrice'] ?? 0) as int;
      int ownerMoney = (gameState!['users']['user$ownerNum']['money'] ?? 0) as int;
      updateData['users']['user$ownerNum'] = {'money': ownerMoney - (price ~/ 2)};

    } else if (event == "priceDown") {
      updateData['board']['b$index'] = {'multiply': 0.5};
    }

    // 🔥 핵심: 모든 변경사항을 한 번에 서버로 전송
    _completeAction(updateData);
  }



  Future<void> _handleIslandEvent(Map<String, dynamic> data) async {
    // IslandDialog로부터 결과 받기 (true: 결제, false: 대기)
    final bool result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IslandDialog(
        user: myIndex,
        gameState: gameState,
      ),
    );

    if (result == true) { // 100만원 지불 선택
      int currentMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;

      _completeAction({
        'users': {
          'user$myIndex': {
            'money': currentMoney - 1000000,
            'islandCount': 0, // 즉시 탈출 처리
          }
        }
      });
      print("💰 무인도 탈출 비용 지불 완료");
    } else {
      // 그냥 쉬기(주사위 굴리기) 선택 시
      // 서버에 알림을 보내서 주사위 버튼을 활성화시킵니다.
      socket.emit('island_wait_complete', {
        'roomId': widget.roomId,
        'playerIndex': myIndex
      });
    }
  }

  Future<void> _handleLandEvent(int pos) async {
    if (gameState == null) {
      _completeAction({});
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
      });
    } else {
      _completeAction({});
    }
  }

  Future<void> _handleTollAndTakeover(Map<String, dynamic> data) async {
    int pos = int.tryParse(data['pos']?.toString() ?? '0') ?? 0;
    int toll = int.tryParse(data['toll']?.toString() ?? '0') ?? 0;
    int ownerIdx = int.tryParse(data['ownerIndex']?.toString() ?? '0') ?? 0;
    int myMoney = int.tryParse(gameState!['users']['user$myIndex']['money']?.toString() ?? '0') ?? 0;

    // 내 땅이면 건설창만 띄우고 종료
    if (ownerIdx == myIndex) {
      await _handleLandEvent(pos);
      return;
    }

    // 1. 통행료 지불 및 파산 체크
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

    // 통행료 지불 후 예상 잔액 업데이트 (인수 비용 계산을 위해)
    int remainingMoney = myMoney - toll;

    // 기본 업데이트 데이터 (통행료 지불 정보)
    Map<String, dynamic> updateData = {
      'users': {
        'user$myIndex': { 'money': remainingMoney },
        'user$ownerIdx': { 'money': (int.tryParse(gameState!['users']['user$ownerIdx']['money']?.toString() ?? '0') ?? 0) + toll }
      }
    };

    // 2. 인수 처리
    int currentLevel = int.tryParse(gameState!['board']['b$pos']['level']?.toString() ?? '0') ?? 0;
    bool takeoverSuccess = false;

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
        takeoverSuccess = true;

        // 1. 서버로 보낼 업데이트 데이터에 소유권 변경 기록
        // 만약 updateData['board']가 null일 수 있으니 안전하게 초기화하며 할당
        updateData['board'] ??= {};
        updateData['board']['b$pos'] = {
          'owner': myIndex.toString(),
          'level': currentLevel // 인수한 시점의 레벨 유지
        };

        // 2. 🔥 매우 중요: Deep Copy (깊은 복사) 수행
        // ConstructionDialog가 "내 땅"이라고 인식하게 만들기 위해 데이터를 완전히 새로 조립합니다.
        Map<String, dynamic> tempGameState = Map<String, dynamic>.from(gameState!);
        Map<String, dynamic> tempBoard = Map<String, dynamic>.from(tempGameState['board'] ?? {});
        Map<String, dynamic> tempTile = Map<String, dynamic>.from(tempBoard['b$pos'] ?? {});

        // 임시 데이터에서 소유권을 나(myIndex)로 강제 변경
        tempTile['owner'] = myIndex.toString();
        tempBoard['b$pos'] = tempTile;
        tempGameState['board'] = tempBoard;

        // 3. 건설창 호출
        final buildResult = await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ConstructionDialog(
            user: myIndex,
            buildingId: pos,
            gameState: tempGameState, // 완전히 '내 소유'로 바뀐 가공 데이터를 전달
          ),
        );

        // 4. 건설 결과 반영
        if (buildResult != null && buildResult is Map) {
          // 서버 전송용 데이터 업데이트 (레벨 변경)
          updateData['board']['b$pos']['level'] = buildResult['level'];

          // 돈 계산: (통행료 지불 후 남은 돈) - (추가 건설비)
          int constructionCost = int.tryParse(buildResult['totalCost']?.toString() ?? '0') ?? 0;
          updateData['users']['user$myIndex']['money'] -= constructionCost;

          print("✅ 인수 후 추가 건설 성공: 레벨 ${buildResult['level']}, 비용 $constructionCost");
        }
      }
    }

    // 최종 결과 서버 전송
    _completeAction(updateData);
  }

  void _completeAction(Map<String, dynamic> stateUpdate) {
    socket.emit('action_complete', {
      'roomId': widget.roomId,
      'stateUpdate': stateUpdate,
    });
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
        child: type == 'land' ? _buildLandContent(tileData, index) : Center(child: Text(tileData['name'], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
      ),
    );
  }



  Widget _buildLandContent(Map<String, dynamic> tileData, int index) {
    final int buildLevel = int.tryParse(tileData['level']?.toString() ?? '0') ?? 0;
    final int owner = int.tryParse(tileData['owner']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () async{
        if (tileData != null && tileData["type"] == "land") {
          final result = await showDialog(context: context, builder: (context) { return DetailPopup(boardNum: index,onNext: (){},roomId: widget.roomId,); });
          if(result != null){
            Map<String, dynamic> fullData = Map<String, dynamic>.from(tileData ?? {});
            fullData.addAll(result);
            showDialog(context: context, builder: (context) => BoardDetail(boardNum: index, data: fullData, roomId: widget.roomId,));
          }
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(flex: 2, child: Container(color: _getAreaColor(index))),
              Expanded(flex: 5, child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tileData["name"] ?? "토지", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  Text(_formatMoney(tileData["tollPrice"] ?? 0), style: TextStyle(fontSize: 6, color: Colors.grey[700])),
                ],
              )),
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
        ],
      ),
    );
  }

  Widget _buildAnimatedPlayer(int playerIdx, double tileSize) {
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