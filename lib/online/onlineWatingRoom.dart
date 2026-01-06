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

  bool _hasNavigated = false; // ✅ 한 번만 이동하도록 플래그

  DocumentReference get _roomDoc => _firestore.collection('online').doc(widget.roomId);
  CollectionReference get _usersCol => _roomDoc.collection('users');

  /// 방 나가기 로직
  Future<void> _exitRoom() async {
    if (socket == null) return;

    try {
      final snapshot = await _usersCol.get();
      final activePlayers = snapshot.docs.where((d) => (d.data() as Map)['type'] == 'P').toList();

      if (activePlayers.length <= 1) {
        // 방 전체 삭제
        WriteBatch batch = _firestore.batch();
        for (var doc in snapshot.docs) batch.delete(doc.reference);
        batch.delete(_roomDoc);
        await batch.commit();
      } else {
        // 내 자리만 비우기
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

      // 서버 신호
      socket!.emit("leave_room", widget.roomId);

      if (mounted) context.go('/onlineRoom');
    } catch (e) {
      debugPrint("퇴장 처리 중 오류: $e");
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
        }, SetOptions(merge: true)); // ✅ merge 적용
      }
    }

    batch.set(_roomDoc, {'status': 'playing'}, SetOptions(merge: true)); // ✅ merge 적용
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로가기 버튼 제어
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _exitRoom();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("대기실 - ${widget.roomId}"),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _exitRoom),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _roomDoc.snapshots(),
          builder: (context, roomSnap) {
            // 1. 게임 시작 상태 감시 (화면 전환)
            if (roomSnap.hasData && roomSnap.data!.exists) {
              final roomData = roomSnap.data!.data() as Map<String, dynamic>;
              final status = roomData['status'];
              if (!_hasNavigated && status == 'playing') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.go('/onlinegameMain', extra: {'roomId': widget.roomId});
                });
              }
            }

            // 2. 플레이어 목록 스트림
            return StreamBuilder<QuerySnapshot>(
              stream: _usersCol.snapshots(), // 유저 목록 실시간 감시
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                // 현재 접속 중인 플레이어('P' 타입) 수 계산
                int activeCount = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['type'] == 'P';
                }).length;

                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: 4, // 4개의 고정 슬롯 표시
                        itemBuilder: (context, index) {
                          // ✅ 핵심 수정: 단순히 docs[index]를 쓰는 게 아니라, user1~user4 이름을 직접 매칭
                          final String targetId = 'user${index + 1}';

                          // docs 리스트에서 ID가 'user1', 'user2'...인 문서를 찾음
                          final userDoc = docs.where((d) => d.id == targetId).firstOrNull;

                          if (userDoc != null) {
                            final userData = userDoc.data() as Map<String, dynamic>;
                            // 유저 타입이 'P'인 경우에만 이름을 표시
                            if (userData['type'] == 'P') {
                              return _buildActiveSlot(userData['name'] ?? "플레이어 ${index + 1}");
                            }
                          }

                          // 문서가 없거나 타입이 'N'이면 대기 중 표시
                          return _buildEmptySlot();
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60),
                          backgroundColor: Colors.orange,
                        ),
                        // 2명 이상일 때만 시작 버튼 활성화
                        onPressed: activeCount >= 2 ? _startGame : null,
                        child: Text("게임 시작 ($activeCount/4)"),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveSlot(String name) => Container(
    decoration: BoxDecoration(
      color: Colors.orange[100],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange, width: 2),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person, color: Colors.orange, size: 40),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    ),
  );

  Widget _buildEmptySlot() => Container(
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[400]!),
    ),
    child: const Center(
      child: Text("대기 중...", style: TextStyle(color: Colors.grey, fontSize: 16)),
    ),
  );
}