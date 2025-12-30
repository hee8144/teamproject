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

  Stream<DocumentSnapshot> get _usersStream => _usersDoc.snapshots();

  /* ================== Firestore helpers ================== */

  Future<void> _addUser(int index, String type) async {
    final turn = await _getNextTurn();
    await _usersDoc.update({
      'user${index + 1}.type': type,
      'user${index + 1}.turn': turn,
    });
  }

  Future<void> _removeUser(int index) async {
    await _usersDoc.update({
      'user${index + 1}.type': 'N',
      'user${index + 1}.turn': 0,
    });
  }

  Future<int> _getNextTurn() async {
    final snapshot = await _usersDoc.get();
    final data = snapshot.data() as Map<String, dynamic>;

    final turns = List.generate(4, (i) {
      return (data['user${i + 1}']['turn'] ?? 0) as int;
    }).where((t) => t > 0).toList();

    if (turns.isEmpty) return 1;
    return turns.reduce((a, b) => a > b ? a : b) + 1;
  }

  int _getDisplayNumber(Map<String, dynamic> data, int index) {
    final entries = List.generate(4, (i) {
      return {
        'id': i,
        'turn': data['user${i + 1}']['turn'] ?? 0,
      };
    }).where((e) => e['turn'] > 0).toList()
      ..sort((a, b) => (a['turn'] as int).compareTo(b['turn'] as int));

    final orderIndex = entries.indexWhere((e) => e['id'] == index);

    // Here we ensure the numbering starts from 1
    return orderIndex == -1 ? 0 : orderIndex + 1; // It now returns from 1
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
            child: StreamBuilder<DocumentSnapshot>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;

                final activeCount = List.generate(4, (i) {
                  return data['user${i + 1}']['type'];
                }).where((t) => t != 'N').length;

                final canStart = activeCount >= 2;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // 🔹 Grid (남은 영역 전부 사용)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 50, 10, 10), // Padding 감소
                        child: _buildLandscapeGrid(data),
                      ),
                    ),

                    // 🔹 게임 시작 버튼 (정중앙)
                    Center(
                      child: _buildStartButton(canStart, context),
                    ),
                  ],
                );
              },
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
  Widget _buildLandscapeGrid(Map<String, dynamic> data) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8, // 세로 공간을 더 줄임
        crossAxisSpacing: 10, // 가로 공간을 더 줄임
        childAspectRatio: 3.3, // 슬롯 크기를 더 줄임 (세로 크기 축소)
      ),
      itemCount: 4,
      itemBuilder: (_, index) => _buildPlayerSlot(data, index),
    );
  }

  /* ================== 슬롯 ================== */
  Widget _buildPlayerSlot(Map<String, dynamic> data, int index) {
    final user = data['user${index + 1}'];
    final String type = user['type'];
    final bool isEmpty = type == 'N';
    final int number = _getDisplayNumber(data, index); // 번호를 1부터 시작하도록 수정

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
                  onTap: () => _addUser(index, 'B'),
                  child: _buildAddButton(Icons.android),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addUser(index, 'P'),
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
        if (!isEmpty && !(index == 3 && type == 'P'))
          Positioned(
            top: 14,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeUser(index),
              child: _buildCircleIcon(Icons.close),
            ),
          ),
      ],
    );
  }

  /* ================== UI ================== */
  Widget _buildStartButton(bool canStart, BuildContext context) {
    return ElevatedButton(
      onPressed: canStart
          ? () => context.go('/gameMain')
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
