import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../network/socket_service.dart';

class OnlineWaitingRoom extends StatefulWidget {
  final String roomId;
  const OnlineWaitingRoom({super.key, required this.roomId});

  @override
  State<OnlineWaitingRoom> createState() => _OnlineWaitingRoomState();
}

class _OnlineWaitingRoomState extends State<OnlineWaitingRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final socket = SocketService().socket;

  bool _hasNavigated = false;

  DocumentReference get _roomDoc => _firestore.collection('online').doc(widget.roomId);
  CollectionReference get _usersCol => _roomDoc.collection('users');

  /// 방 나가기
  Future<void> _exitRoom() async {
    if (socket == null) return;
    try {
      final snapshot = await _usersCol.get();
      final activePlayers = snapshot.docs.where((d) => (d.data() as Map)['type'] == 'P').toList();

      if (activePlayers.length <= 1) {
        WriteBatch batch = _firestore.batch();
        for (var doc in snapshot.docs) batch.delete(doc.reference);
        batch.delete(_roomDoc);
        await batch.commit();
      } else {
        await _firestore.runTransaction((transaction) async {
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['id'] == socket!.id) {
              transaction.update(doc.reference, {
                'type': 'N',
                'id': FieldValue.delete(),
                'name': FieldValue.delete(),
                'isOnline': false,
              });
              break;
            }
          }
        });
      }
      socket!.emit("leave_room", widget.roomId);
      if (mounted) context.go('/onlineRoom');
    } catch (e) {
      debugPrint("퇴장 오류: $e");
      if (mounted) context.go('/onlineRoom');
    }
  }

  /// 게임 시작
  Future<void> _startGame() async {
    if (socket == null) return;
    socket!.emit("start_game", widget.roomId);

    final usersSnapshot = await _usersCol.get();
    WriteBatch batch = _firestore.batch();

    for (var doc in usersSnapshot.docs) {
      final userData = doc.data() as Map<String, dynamic>;
      if (userData['type'] == 'P') {
        batch.set(doc.reference, {
          'money': 7000000,
          'totalMoney': 7000000,
          'position': 0,
          'level': 1,
          'turn': 0,
          'rank': 4,
          'isOnline': true,
        }, SetOptions(merge: true));
      }
    }
    batch.set(_roomDoc, {'status': 'playing'}, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _exitRoom();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text("대기실 (${widget.roomId})",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)), // 폰트 크기 조정
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: _exitRoom,
          ),
        ),
        body: Stack(
          children: [
            // 1. 배경
            Positioned.fill(
              child: Image.asset("assets/board-background.PNG", fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.5)), // 배경 조금 더 어둡게
            ),

            // 2. 내용
            SafeArea(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _roomDoc.snapshots(),
                builder: (context, roomSnap) {
                  if (roomSnap.hasData && roomSnap.data!.exists) {
                    final roomData = roomSnap.data!.data() as Map<String, dynamic>;
                    if (!_hasNavigated && roomData['status'] == 'playing') {
                      _hasNavigated = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        context.go('/onlinegameMain', extra: {'roomId': widget.roomId});
                      });
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _usersCol.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                      final docs = snapshot.data!.docs;
                      int activeCount = docs.where((d) => (d.data() as Map)['type'] == 'P').length;

                      return Column(
                        children: [
                          // 상단 여백 축소
                          const SizedBox(height: 10),
                          const Text("플레이어를 기다리고 있습니다...",
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 10),

                          // 유저 카드 그리드 (Expanded로 최대한 공간 확보)
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // 2열
                                childAspectRatio: 2.8, // 💡 가로로 긴 비율 (세로 공간 절약 핵심)
                                mainAxisSpacing: 15,
                                crossAxisSpacing: 30,
                              ),
                              itemCount: 4,
                              itemBuilder: (context, index) {
                                final String targetId = 'user${index + 1}';
                                final userDoc = docs.where((d) => d.id == targetId).firstOrNull;

                                bool isActive = false;
                                String userName = "";

                                if (userDoc != null) {
                                  final userData = userDoc.data() as Map<String, dynamic>;
                                  if (userData['type'] == 'P') {
                                    isActive = true;
                                    userName = userData['name'] ?? "플레이어 ${index + 1}";
                                  }
                                }

                                return isActive
                                    ? _buildActiveSlot(index, userName)
                                    : _buildEmptySlot();
                              },
                            ),
                          ),

                          // 시작 버튼 (크기 및 여백 조정)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(40, 0, 40, 20), // 아래쪽 패딩만 줌
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12), // 버튼 높이 줄임
                                backgroundColor: activeCount >= 2 ? const Color(0xFF5D4037) : Colors.grey,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 8,
                              ),
                              onPressed: activeCount >= 2 ? _startGame : null,
                              child: Text(
                                activeCount >= 2 ? "게임 시작 ($activeCount/4)" : "인원 부족 ($activeCount/4)",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 [수정] 활성 유저 카드 (가로형 레이아웃 Row 사용)
  Widget _buildActiveSlot(int index, String name) {
    List<Color> colors = [Colors.redAccent, Colors.blueAccent, Colors.green, Colors.purpleAccent];
    Color myColor = colors[index % 4];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF5D4037), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(2, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row( // 💡 Column -> Row 변경
        children: [
          CircleAvatar(
            radius: 20, // 아이콘 크기 축소
            backgroundColor: myColor.withOpacity(0.2),
            child: Icon(Icons.person, color: myColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3E2723)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: myColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("준비 완료", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💡 [수정] 빈 자리 카드 (가로형 레이아웃 Row 사용)
  Widget _buildEmptySlot() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Row( // 💡 Column -> Row 변경
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_outline, color: Colors.white38, size: 24),
          SizedBox(width: 8),
          Text("대기 중...", style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}