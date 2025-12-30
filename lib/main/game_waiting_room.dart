import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ==================== 게임 대기방 ====================
class GameWaitingRoom extends StatefulWidget {
  final String? typesQuery; // 쿼리 파라미터로 전달받는 types

  const GameWaitingRoom({super.key, this.typesQuery});

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// games / users 단일 문서
  DocumentReference get _usersDoc =>
      _firestore.collection('games').doc('users');

  // 슬롯을 변경할 때 DB에 바로 반영하지 않고 임시로 저장할 리스트
  List<String> tempTypes = ['N', 'N', 'N', 'P']; // 첫 번째 슬롯에 'P' (플레이어 1) 설정
  List<int> playerOrder = []; // 플레이어가 추가된 순서를 저장하는 리스트

  @override
  void initState() {
    super.initState();

    // 생성자에서 전달받은 typesQuery를 tempTypes에 반영
    if (widget.typesQuery != null) {
      final typesList = widget.typesQuery!.split(',');
      tempTypes = typesList;
    }
  }

  /* ================== Firestore helpers ================== */

  // 게임 시작 버튼 클릭 시, 임시 리스트에 저장된 데이터를 DB에 반영
  Future<void> _updateUsersInDB() async {
    await _usersDoc.update({
      'user1.type': tempTypes[0],
      'user2.type': tempTypes[1],
      'user3.type': tempTypes[2],
      'user4.type': tempTypes[3],
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ================= 배경 =================
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.05)),

          // ================= 메인 =================
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔹 Grid (남은 영역 전부 사용)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
                    child: _buildLandscapeGrid(),
                  ),
                ),
              ],
            ),
          ),

          // ================= 게임 시작 버튼 =================
          Positioned(
            bottom: size.height / 2 - 50,
            left: size.width / 2 - 30,
            child: _buildStartButton(),
          ),

          // ================= 나가기 버튼 =================
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

  /* ================== 가로 ================== */
  Widget _buildLandscapeGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 10,
        childAspectRatio: 3.3,
      ),
      itemCount: 4,
      itemBuilder: (_, index) => _buildPlayerSlot(index),
    );
  }

  /* ================== 슬롯 ================== */
  Widget _buildPlayerSlot(int index) {
    final String type = tempTypes[index];
    final bool isEmpty = type == 'N';
    final int playerNumber =
    isEmpty ? playerOrder.length + 1 : playerOrder.indexOf(index) + 1;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6).withOpacity(isEmpty ? 0.6 : 1.0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD7C0A1),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isEmpty
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    _updateTempUser(index, 'B');
                  },
                  child: _buildAddButton(Icons.android),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _updateTempUser(index, 'P');
                  },
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
                      ? '봇${playerNumber + 1}'
                      : '플레이어${playerNumber + 1}',
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
              onTap: () {
                _updateTempUser(index, 'N');
              },
              child: _buildCircleIcon(Icons.close),
            ),
          ),
      ],
    );
  }

  /* ================== 임시 상태 업데이트 ================== */
  void _updateTempUser(int index, String type) {
    setState(() {
      tempTypes[index] = type;
      if (type != 'N') {
        playerOrder.add(index);
      } else {
        playerOrder.remove(index);
      }
    });
  }

  /* ================== 게임 시작 버튼 ================== */
  Widget _buildStartButton() {
    bool canStart = tempTypes.where((t) => t != 'N').length >= 2;
    return ElevatedButton(
      onPressed: canStart
          ? () async {
        await _updateUsersInDB();
        context.go('/gameMain');
      }
          : null,
      child: const Text('게임 시작!'),
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
        color: const Color(0xFFFDF5E6).withOpacity(0.9),
        border: Border.all(color: const Color(0xFFD7C0A1), width: 2),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF5D4037)),
    );
  }
}
