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
    return WillPopScope(
      onWillPop: () async {
        await _exitRoom();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("대기실 - ${widget.roomId}"),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _exitRoom),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _roomDoc.snapshots(),
          builder: (context, roomSnap) {
            if (roomSnap.hasData && roomSnap.data!.exists) {
              final status = (roomSnap.data!.data() as Map)['status'];
              if (!_hasNavigated && status == 'playing') {
                _hasNavigated = true; // ✅ 상태 변수 사용
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.go('/onlinegameMain', extra: {'roomId': widget.roomId});
                });
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _usersCol.orderBy(FieldPath.documentId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                int activeCount = docs.where((d) => (d.data() as Map)['type'] == 'P').length;

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
                        itemCount: 4,
                        itemBuilder: (context, index) {
                          if (index < docs.length) {
                            final userData = docs[index].data() as Map<String, dynamic>;
                            if (userData['type'] == 'P') return _buildActiveSlot(userData['name'] ?? "플레이어");
                          }
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
      border: Border.all(color: Colors.orange),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [const Icon(Icons.person, color: Colors.orange), Text(name)],
    ),
  );

  Widget _buildEmptySlot() => Container(
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey),
    ),
    child: const Center(child: Text("대기 중...")),
  );
}
