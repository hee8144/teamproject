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
  List<String> tempTypes = ['N', 'N', 'N', 'P']; // 첫 번째 슬롯에 'P' (플레이어 1) 설정
  List<int> playerOrder = []; // 플레이어가 추가된 순서를 저장하는 리스트

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
                Expanded(  // Use Expanded to automatically take the available space
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 50, 10, 10), // Padding 감소
                    child: _buildLandscapeGrid(),
                  ),
                ),
              ],
            ),
          ),

          // ================= 게임 시작 버튼 =================
          Positioned(
            bottom: size.height / 2 - 50, // 화면 하단에 고정
            left: size.width / 2 - 30, // 가로 중앙에 배치 (버튼 크기 200px 기준)
            child: _buildStartButton(), // 게임 시작 버튼을 Stack 위에 고정
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
    final int playerNumber = isEmpty ? playerOrder.length + 1 : playerOrder.indexOf(index) + 1;

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
                  type == 'B' ? '봇${playerNumber + 1}' : '플레이어${playerNumber + 1}', // 플레이어 번호 1부터 시작
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
        // 4번 슬롯 (index == 3)에 대해서 X 버튼을 표시하지 않음
        if (!isEmpty && index != 3) // X 버튼은 4번 슬롯을 제외한 슬롯에서만 표시
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
      if (type != 'N') {
        playerOrder.add(index); // 플레이어나 봇이 추가되면 순서대로 저장
      } else {
        playerOrder.remove(index); // 빈 상태로 설정되면 해당 인덱스를 playerOrder에서 제거
      }
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
