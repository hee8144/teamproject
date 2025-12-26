import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameWaitingRoom extends StatefulWidget {
  const GameWaitingRoom({super.key});

  @override
  State<GameWaitingRoom> createState() => _GameWaitingRoomState();
}

class _GameWaitingRoomState extends State<GameWaitingRoom> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  /// 🔢 슬롯 index → 표시 번호 매핑
  /// [좌상, 우상, 좌하, 우하] = [2, 4, 3, 1]
  final List<int> displayOrder = [2, 4, 3, 1];

  Stream<DocumentSnapshot<Map<String, dynamic>>> get usersStream =>
      fs.collection('games').doc('users').snapshots();

  @override
  void initState() {
    super.initState();
    _initPlayerFour();
  }

  /// ✅ 처음 입장 시 4번 자리를 플레이어로 자동 세팅
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
          // ================== 배경 ==================
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

          // ================== 메인 콘텐츠 ==================
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

                  return Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: isLandscape
                        ? _buildLandscapeGrid(users)
                        : _buildPortraitGrid(users),
                  );
                },
              ),
            ),
          ),

          // ================== 나가기 X 버튼 ==================
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

          // ================== 게임 시작 버튼 ==================
          Positioned(
            bottom: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: _buildStartButton(),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== 플레이어 그리드 - 세로 ================== */
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

  /* ================== 플레이어 그리드 - 가로 ================== */
  Widget _buildLandscapeGrid(Map<String, dynamic> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossCount = 2;
        const double spacing = 12;

        final double totalWidth =
            constraints.maxWidth - spacing * (crossCount - 1);
        final double totalHeight =
            constraints.maxHeight - spacing * (crossCount - 1);

        final double slotWidth = totalWidth / crossCount;
        final double slotHeight = totalHeight / crossCount;

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

  /* ================== 플레이어 슬롯 ================== */
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
        if (!isEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _clearUser(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                  border: Border.all(
                    color: const Color(0xFFD7C0A1),
                  ),
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF5D4037),
                ),
              ),
            ),
          ),
      ],
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

  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: () {
        debugPrint("게임 시작!");
      },
      child: const Text("게임 시작!"),
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
