import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ==================== 게임 대기방 ====================
class GameWaitingRoom extends StatefulWidget {
  final String? typesQuery;

  const GameWaitingRoom({super.key, this.typesQuery});

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// games / users 단일 문서
  DocumentReference get _usersDoc =>
      _firestore.collection('games').doc('users');

  List<String> tempTypes = ['N', 'N', 'N', 'P'];
  List<int> playerOrder = [];

  @override
  void initState() {
    super.initState();

    if (widget.typesQuery != null) {
      tempTypes = widget.typesQuery!.split(',');
    }

    playerOrder = [];
    if (tempTypes[3] != 'N') playerOrder.add(3);
    if (tempTypes[0] != 'N') playerOrder.add(0);
    for (int i = 1; i <= 2; i++) {
      if (tempTypes[i] != 'N') playerOrder.add(i);
    }
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
          // 1️⃣ 플레이어 구성 반영
          await _updateUsersInDB();

          // 2️⃣ 게임 상태 초기화
          await _resetGameStateOnly();

          // 3️⃣ 게임 시작
          context.go('/gameMain');
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
