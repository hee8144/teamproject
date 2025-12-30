import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ==================== 게임 대기방 ====================
class GameWaitingRoom extends StatefulWidget {
  const GameWaitingRoom({super.key});

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// games / users 단일 문서
  DocumentReference get _usersDoc =>
      _firestore.collection('games').doc('users');

  // 슬롯을 변경할 때 DB에 바로 반영하지 않고 임시로 저장할 리스트
  List<String> tempTypes = ['N', 'N', 'N', 'N']; // 초기 상태는 모두 N (빈 슬롯)

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

  int _getDisplayNumber(Map<String, dynamic> data, int index) {
    // 슬롯 상태가 'N'이 아닌 경우만 필터링
    final entries = List.generate(4, (i) {
      return {
        'id': i,
        'type': data['user${i + 1}']['type'],
      };
    }).where((e) => e['type'] != 'N').toList();

    // 'type'이 'N'이 아닌 슬롯만 순서대로 번호 부여
    final orderIndex = entries.indexWhere((e) => e['id'] == index);

    // 번호는 1부터 시작
    return orderIndex == -1 ? 0 : orderIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
                Expanded(  // Use Expanded to automatically take the available space
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 50, 10, 10), // Padding 감소
                    child: _buildLandscapeGrid(),
                  ),
                ),

                // 🔹 게임 시작 버튼 (정중앙)
                _buildStartButton(),
              ],
            ),
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8, // 세로 공간을 더 줄임
        crossAxisSpacing: 10, // 가로 공간을 더 줄임
        childAspectRatio: 3.3, // 슬롯 크기를 더 줄임 (세로 크기 축소)
      ),
      itemCount: 4,
      itemBuilder: (_, index) => _buildPlayerSlot(index),
    );
  }

  /* ================== 슬롯 ================== */
  Widget _buildPlayerSlot(int index) {
    final String type = tempTypes[index];
    final bool isEmpty = type == 'N';
    final int number = index + 1; // 번호는 1부터 시작

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
                    _updateTempUser(index, 'B'); // 임시 리스트에 봇 추가
                  },
                  child: _buildAddButton(Icons.android),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _updateTempUser(index, 'P'); // 임시 리스트에 플레이어 추가
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
                  type == 'B' ? '봇$number' : '플레이어$number',
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
        if (!isEmpty) // 슬롯이 비어 있지 않을 때만 X 버튼을 표시
          Positioned(
            top: 14,
            right: 8,
            child: GestureDetector(
              onTap: () {
                _updateTempUser(index, 'N'); // 해당 슬롯만 빈 상태로 설정
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
      tempTypes[index] = type; // 임시 상태 업데이트
    });
  }

  /* ================== 게임 시작 버튼 ================== */
  Widget _buildStartButton() {
    bool canStart = tempTypes.where((t) => t != 'N').length >= 2;
    return ElevatedButton(
      onPressed: canStart
          ? () async {
        await _updateUsersInDB(); // 게임 시작 시 DB에 반영
        context.go('/gameMain'); // 게임 시작 화면으로 이동
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
