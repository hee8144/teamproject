import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

import '../Popup/Construction.dart';
import '../Popup/Takeover.dart';
import '../Popup/Bankruptcy.dart';
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

  final GlobalKey<onlineDiceAppState> diceAppKey = GlobalKey<onlineDiceAppState>();

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io('http://localhost:3000',
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
    } else {
      _completeAction({});
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

    // 👈 혹시 모를 이중 체크: 내 땅이면 여기서 중단
    if (ownerIdx == myIndex) {
      await _handleLandEvent(pos);
      return;
    }

    print("DEBUG: 통행료 지불 시작 - 금액: $toll, 주인: $ownerIdx");

    // 파산 체크
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

    // 통행료 지불 데이터 생성
    Map<String, dynamic> updateData = {
      'users': {
        'user$myIndex': { 'money': myMoney - toll },
        'user$ownerIdx': { 'money': (int.tryParse(gameState!['users']['user$ownerIdx']['money']?.toString() ?? '0') ?? 0) + toll }
      }
    };

    // 인수 팝업 (랜드마크가 아닐 때만)
    int currentLevel = int.tryParse(gameState!['board']['b$pos']['level']?.toString() ?? '0') ?? 0;
    if (currentLevel < 4) {
      final bool? takeover = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => TakeoverDialog(buildingId: pos, user: myIndex),
      );
      // 인수를 선택했다면 소유주 변경 데이터를 추가
      if (takeover == true) {
        updateData['board'] = { 'b$pos': { 'owner': myIndex.toString() } };
      }
    }

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
        child: type == 'land' ? _buildLandContent(tileData, index) : Center(child: Text(type, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildLandContent(Map<String, dynamic> tileData, int index) {
    final int buildLevel = int.tryParse(tileData['level']?.toString() ?? '0') ?? 0;
    final int owner = int.tryParse(tileData['owner']?.toString() ?? '0') ?? 0;

    return Stack(
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