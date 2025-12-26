import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../game/gameMain.dart';

class GameWaitingRoom extends StatefulWidget {
  const GameWaitingRoom({super.key});

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  /// [좌상, 우상, 좌하, 우하] = [2, 4, 3, 1]
  final List<int> displayOrder = [2, 4, 3, 1];

  Stream<DocumentSnapshot<Map<String, dynamic>>> get usersStream =>
      fs.collection('games').doc('users').snapshots();

  @override
  void initState() {
    super.initState();
    _initPlayerFour();
  }

  /// 처음 입장 시 4번 자리를 플레이어로 자동 세팅
  Future<void> _initPlayerFour() async {
    final doc = await fs.collection('games').doc('users').get();
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) return;

    final user4 = data['user4'];
    if (user4 != null && user4['type'] == "N") {
      await fs.collection('games').doc('users').update({
        'user4.type': "P",
      });
    }
  }

  Future<void> _updateUserType(int index, String type) async {
    await fs.collection('games').doc('users').update({
      'user${index + 1}.type': type,
    });
  }

  Future<void> _clearUser(int index) async {
    await _updateUserType(index, "N");
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Stack(
        children: [
          // ================= 배경 =================
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.05)),

          // ================= 메인 =================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: usersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final users = snapshot.data!.data()!;

                  final int activeCount = List.generate(4, (i) {
                    return users['user${i + 1}']['type'];
                  }).where((type) => type != "N").length;

                  final bool canStart = activeCount >= 2;

                  return Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Stack(
                      children: [
                        isLandscape
                            ? _buildLandscapeGrid(users)
                            : _buildPortraitGrid(users),

                        Center(
                          child: _buildStartButton(canStart),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ================= 나가기 버튼 (유지) =================
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: _buildCircleIcon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== 세로 ================== */
  Widget _buildPortraitGrid(Map<String, dynamic> users) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 1.2,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        final user = users['user${index + 1}'];
        return _buildPlayerSlot(index, user['type']);
      },
    );
  }

  /* ================== 가로 ================== */
  Widget _buildLandscapeGrid(Map<String, dynamic> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossCount = 2;
        const double spacing = 12;

        final double slotWidth =
            (constraints.maxWidth - spacing) / crossCount;
        final double slotHeight =
            (constraints.maxHeight - spacing) / crossCount;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: slotWidth / slotHeight,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            final user = users['user${index + 1}'];
            return _buildPlayerSlot(index, user['type']);
          },
        );
      },
    );
  }

  /* ================== 슬롯 ================== */
  Widget _buildPlayerSlot(int index, String type) {
    final bool isEmpty = type == "N";
    final int displayNumber = displayOrder[index];

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
                  onTap: () => _updateUserType(index, "B"),
                  child: _buildAddButton(Icons.android),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _updateUserType(index, "P"),
                  child: _buildAddButton(Icons.person_add),
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == "B" ? Icons.android : Icons.person,
                  size: 30,
                  color: const Color(0xFF5D4037),
                ),
                const SizedBox(height: 6),
                Text(
                  type == "B"
                      ? "봇$displayNumber"
                      : "플레이어$displayNumber",
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

        // ⭐ 슬롯 내부 X 버튼 위치만 아래로 이동
        if (!isEmpty && !(index == 3 && type == "P"))
          Positioned(
            top: 14, // ← 기존 8 → 14
            right: 8,
            child: GestureDetector(
              onTap: () => _clearUser(index),
              child: _buildCircleIcon(Icons.close),
            ),
          ),
      ],
    );
  }

  Widget _buildStartButton(bool canStart) {
    return ElevatedButton(
      onPressed: canStart
          ? () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameMain()),
        );
      }
          : null,
      child: const Text("게임 시작!"),
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
