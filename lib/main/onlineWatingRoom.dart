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

  DocumentReference get _roomDoc => _firestore.collection('online').doc(widget.roomId);
  CollectionReference get _usersCol => _roomDoc.collection('users');

  /// 방 나가기 로직 (방 삭제 포함)
  Future<void> _exitRoom() async {
    if (socket == null) return;

    try {
      final snapshot = await _usersCol.get();
      final activePlayers = snapshot.docs.where((d) => (d.data() as Map)['type'] == 'P').toList();

      // 내가 마지막 인원이거나, 방장(user01)인 경우 방 전체 삭제 시도
      if (activePlayers.length <= 1) {
        WriteBatch batch = _firestore.batch();
        // 하위 유저 문서 삭제
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        // 방 문서 삭제
        batch.delete(_roomDoc);
        await batch.commit();
      } else {
        // 남은 인원이 있으면 내 자리만 비움
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

      // 서버에도 신호 전송
      socket!.emit("leave_room", widget.roomId);

      if (mounted) {
        context.go('/onlineRoom');
      }
    } catch (e) {
      debugPrint("퇴장 처리 중 오류: $e");
      if (mounted) context.go('/onlineRoom');
    }
  }

  /// 게임 시작 로직
  Future<void> _startGame() async {
    final usersSnapshot = await _usersCol.get();
    WriteBatch batch = _firestore.batch();

    for (var doc in usersSnapshot.docs) {
      final userData = doc.data() as Map<String, dynamic>;
      if (userData['type'] == 'P') {
        batch.update(doc.reference, {
          'money': 7000000, 'totalMoney': 7000000, 'position': 0,
          'level': 1, 'turn': 0, 'rank': 4, 'isOnline': true,
        });
      }
    }

    batch.update(_roomDoc, {'status': 'playing'});
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
          stream: _roomDoc.snapshots(), // 방 상태 감시
          builder: (context, roomSnap) {
            if (roomSnap.hasData && roomSnap.data!.exists) {
              final status = (roomSnap.data!.data() as Map)['status'];
              if (status == 'playing') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) context.go('/gameMain', extra: widget.roomId);
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
                          crossAxisCount: 2, childAspectRatio: 1.5, mainAxisSpacing: 10, crossAxisSpacing: 10,
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
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.orange),
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
    decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.person, color: Colors.orange), Text(name)]),
  );

  Widget _buildEmptySlot() => Container(
    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey)),
    child: const Center(child: Text("대기 중...")),
  );
}