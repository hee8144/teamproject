import 'package:cloud_firestore/cloud_firestore.dart';

class GameInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //DB games 컬렉션 안의 board 문서 안의 각 owner를 초기화합니다.
  //DB games 컬렉션 안의 users 문서 안의 각종 정보들을 초기화합니다.

  /// games / users 문서
  DocumentReference get _usersDoc =>
      _firestore.collection('games').doc('users');

  /// ================== 보드(board) 전체 초기화 ==================
  Future<void> initializeBoardLayout() async {
    Map<String, dynamic> fullBoardData = {};
    int landCount = 0;

    for (int i = 0; i < 28; i++) {
      String key = "b$i";
      String type = "land";
      String? name;

      if (i == 0) { type = "start"; name = "출발지"; }
      else if (i == 7) { type = "island"; name = "무인도"; }
      else if (i == 14) { type = "festival"; name = "지역축제"; }
      else if (i == 21) { type = "travel"; name = "국내여행"; }
      else if (i == 26) { type = "tax"; name = "국세청"; }
      else if ([3, 10, 17, 24].contains(i)) { type = "chance"; name = "찬스"; }

      Map<String, dynamic> blockData = {
        "index": i,
        "type": type,
        "name": name,
      };

      if (type == "land") {
        int calculatedToll = 100000 + (landCount * 10000);
        int group = 0;

        if (i == 1 || i == 2) group = 1;
        else if (i >= 4 && i <= 6) group = 2;
        else if (i == 8 || i == 9) group = 3;
        else if (i >= 11 && i <= 13) group = 4;
        else if (i == 15 || i == 16) group = 5;
        else if (i >= 18 && i <= 20) group = 6;
        else if (i == 22 || i == 23) group = 7;
        else if (i == 25 || i == 27) group = 8;

        blockData.addAll({
          "name": "일반 땅 ${landCount + 1}",
          "level": 0,
          "owner": "N",
          "tollPrice": calculatedToll,
          "isFestival": false,
          "multiply": 1,
          "group": group,
        });

        landCount++;
      }

      fullBoardData[key] = blockData;
    }

    await _firestore.collection("games").doc("board").set(fullBoardData);
  }

  /// ================== 게임 상태만 초기화 ==================
  Future<void> resetGameStateOnly() async {
    final snapshot = await _usersDoc.get();
    final data = snapshot.data() as Map<String, dynamic>?;

    if (data == null) return;

    Map<String, dynamic> updates = {};

    for (int i = 1; i <= 4; i++) {
      final user = data['user$i'];
      if (user == null) continue;

      final String type = user['type'];
      if (type == 'P' || type == 'B') {
        updates['user$i.money'] = 7000000;
        updates['user$i.totalMoney'] = 7000000;
        updates['user$i.position'] = 0;
        updates['user$i.card'] = 'N';
        updates['user$i.level'] = 1;
        updates['user$i.rank'] = 0;
        updates['user$i.turn'] = 0;
        updates['user$i.double'] = 0;
        updates['user$i.islandCount'] = 0;
        updates['user$i.isTraveling'] = false;
        updates['user$i.isDoubleToll'] = false;
      }
    }

    if (updates.isNotEmpty) {
      await _usersDoc.update(updates);
    }
  }
}
