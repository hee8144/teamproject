import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../game/game_initializer.dart';
import '../widgets/loading_screen.dart';


/// ==================== 게임 대기방 =================
class GameWaitingRoom extends StatefulWidget {
  GameWaitingRoom({super.key}); // const 제거, typesQuery 제거

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GameInitializer _gameInitializer = GameInitializer();

  /// games / users 단일 문서
  DocumentReference get _usersDoc =>
      _firestore.collection('games').doc('users');

  /// ================== 보드(board) 전체 초기화 ==================
  Future<void> _initializeBoardLayout() async {
    Map<String, dynamic> fullBoardData = {};
    int landCount = 0;

    for (int i = 0; i < 28; i++) {
      String key = "b$i";
      String type = "land";
      String? name;

      if (i == 0) { type = "start"; name = "출발지"; }
      else if (i == 7) { type = "island"; name = "무인도"; }
      else if (i == 14) { type = "festival"; name = "지역축제"; }
      else if (i == 21) { type = "travel"; name = "국내여행"; }
      else if (i == 26) { type = "tax"; name = "국세청"; }
      else if ([3, 10, 17, 24].contains(i)) { type = "chance"; name = "찬스"; }

      Map<String, dynamic> blockData = {
        "index": i,
        "type": type,
        "name": name,
      };

      if (type == "land") {
        int calculatedToll = 100000 + (landCount * 10000);
        int group = 0;

        if (i == 1 || i == 2) group = 1;
        else if (i >= 4 && i <= 6) group = 2;
        else if (i == 8 || i == 9) group = 3;
        else if (i >= 11 && i <= 13) group = 4;
        else if (i == 15 || i == 16) group = 5;
        else if (i >= 18 && i <= 20) group = 6;
        else if (i == 22 || i == 23) group = 7;
        else if (i == 25 || i == 27) group = 8;

        blockData.addAll({
          "name": "일반 땅 ${landCount + 1}",
          "level": 0,
          "owner": "N",
          "tollPrice": calculatedToll,
          "isFestival": false,
          "multiply": 1,
          "group": group,
        });

        landCount++;
      }

      fullBoardData[key] = blockData;
    }

    await _firestore.collection("games").doc("board").set(fullBoardData);
  }


  List<String> tempTypes = ['N', 'N', 'N', 'P'];
  List<int> playerOrder = [];

  @override
  void initState() {
    super.initState();
    _initializePlayersFromDB();
  }

  /// ================== DB에서 한 번만 플레이어 타입 초기화 ==================
  Future<void> _initializePlayersFromDB() async {
    final snapshot = await _usersDoc.get();
    final data = snapshot.data() as Map<String, dynamic>?;

    if (data == null) return;

    List<String> types = ['N', 'N', 'N', 'N'];
    for (int i = 1; i <= 4; i++) {
      final user = data['user$i'];
      if (user == null || user['type'] == null) continue;

      String dbType = user['type'];
      // D → P, BD → B 처리
      if (dbType == 'D') {
        types[i - 1] = 'P';
      } else if (dbType == 'BD') {
        types[i - 1] = 'B';
      } else {
        types[i - 1] = dbType;
      }
    }

    setState(() {
      tempTypes = types;

      playerOrder = [];
      if (tempTypes[3] != 'N') playerOrder.add(3);
      if (tempTypes[0] != 'N') playerOrder.add(0);
      for (int i = 1; i <= 2; i++) {
        if (tempTypes[i] != 'N') playerOrder.add(i);
      }
    });
  }

  /// ================== 플레이어 type DB 반영 ==================
  Future<void> _updateUsersInDB() async {
    await _usersDoc.update({
      'user1.type': tempTypes[0],
      'user2.type': tempTypes[1],
      'user3.type': tempTypes[2],
      'user4.type': tempTypes[3],
    });
  }

  /// ================== 게임 상태만 초기화 ==================
  Future<void> _resetGameStateOnly() async {
    final snapshot = await _usersDoc.get();
    final data = snapshot.data() as Map<String, dynamic>?;

    if (data == null) return;

    Map<String, dynamic> updates = {};

    for (int i = 1; i <= 4; i++) {
      final user = data['user$i'];
      if (user == null) continue;

      final String type = user['type'];
      if (type == 'P' || type == 'B') {
        updates['user$i.money'] = 7000000;
        updates['user$i.totalMoney'] = 7000000;
        updates['user$i.position'] = 0;
        updates['user$i.card'] = 'N';
        updates['user$i.level'] = 1;
        updates['user$i.rank'] = 0;
        updates['user$i.turn'] = 0;
        updates['user$i.double'] = 0;
        updates['user$i.islandCount'] = 0;
        updates['user$i.isTraveling'] = false;
      }
    }

    if (updates.isNotEmpty) {
      await _usersDoc.update(updates);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// ================= 배경 =================
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.05)),

          /// ================= 메인 =================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildPlayerSlot(0)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildPlayerSlot(1)),
                    ],
                  ),
                  _buildStartButton(),
                  Row(
                    children: [
                      Expanded(child: _buildPlayerSlot(2)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildPlayerSlot(3)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          /// ================= 나가기 버튼 =================
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => context.go('/main'),
                child: _buildCircleIcon(Icons.arrow_back),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== 슬롯 ================== */
  Widget _buildPlayerSlot(int index) {
    final String type = tempTypes[index];
    final bool isEmpty = type == 'N';

    final int playerNumber =
    isEmpty ? playerOrder.length + 1 : playerOrder.indexOf(index) + 1;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, minHeight: 120),
      child: AspectRatio(
        aspectRatio: 4 / 1,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDF5E6)
                    .withOpacity(isEmpty ? 0.6 : 1.0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD7C0A1), width: 1.5),
              ),
              child: Center(
                child: isEmpty
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _updateTempUser(index, 'B'),
                      child: _buildAddButton(Icons.android),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _updateTempUser(index, 'P'),
                      child: _buildAddButton(Icons.person_add),
                    ),
                  ],
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type == 'B' ? Icons.android : Icons.person,
                      size: 30,
                      color: const Color(0xFF5D4037),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type == 'B'
                          ? '봇$playerNumber'
                          : '플레이어$playerNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isEmpty && index != 3)
              Positioned(
                top: 14,
                right: 8,
                child: GestureDetector(
                  onTap: () => _updateTempUser(index, 'N'),
                  child: _buildCircleIcon(Icons.close),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /* ================== 상태 변경 ================== */
  void _updateTempUser(int index, String type) {
    setState(() {
      tempTypes[index] = type;
      if (type != 'N') {
        if (!playerOrder.contains(index)) {
          playerOrder.add(index);
        }
      } else {
        playerOrder.remove(index);
      }
    });
  }

  /* ================== 게임 시작 버튼 ================== */
  Widget _buildStartButton() {
    final bool canStart =
        tempTypes.where((t) => t != 'N').length >= 2;

    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: canStart
            ? () async {
          try {
            // 1️⃣ 보드 초기화
            await _gameInitializer.initializeBoardLayout();

            // 2️⃣ 플레이어 타입 반영
            await _updateUsersInDB();

            // 3️⃣ 유저 상태 초기화
            await _gameInitializer.resetGameStateOnly();
          } catch (e) {
            debugPrint("초기화 중 오류: $e");
          }

          // 4️⃣ 즉시 게임 시작 (로딩은 GameMain에서 담당)
          if (context.mounted) {
            context.go('/gameMain');
          }
        }
            : null,
        child: const Text('게임 시작!'),
      ),
    );
  }

  Widget _buildAddButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.8),
        border: Border.all(color: const Color(0xFFD7C0A1)),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF8D6E63)),
    );
  }

  Widget _buildCircleIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
        border: Border.all(color: const Color(0xFFD7C0A1), width: 2),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF5D4037)),
    );
  }
}
