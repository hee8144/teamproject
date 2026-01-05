import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:teamproject/main/onlineWatingRoom.dart';
import 'package:teamproject/online/onlineMain.dart';
import '../firebase_options.dart';
import 'game/gameMain.dart';
import 'main/login.dart';
import 'main/mainUI.dart';
import 'main/game_rule.dart';
import 'main/game_waiting_room.dart';
import 'main/game_result.dart';
import 'online/onlineRoomList.dart';
import 'package:flutter/services.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 가로모드 강제 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}


final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => Login()),
    GoRoute(path: '/main', builder: (context, state) => MainScreen()),
    GoRoute(path: '/onlinemain', builder: (context, state) => onlineMainScreen()),
    GoRoute(path: '/onlineRoom', builder: (context, state) => OnlineRoomListPage()),
    GoRoute(
      path: '/onlineWaitingRoom/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return OnlineWaitingRoom(roomId: roomId);
      },
    ),
    GoRoute(path: '/gameRule', builder: (context, state) => GameRulePage()),
    GoRoute(path: '/gameWaitingRoom', builder: (context, state) => GameWaitingRoom()),
    GoRoute(
      path: '/gameResult',
      builder: (context, state) {
        // ✅ GoRouter 7.x 이상에서는 state.uri.queryParameters 사용
        final victoryType = state.uri.queryParameters['victoryType'] ?? 'turn_limit';
        final winnerName = state.uri.queryParameters['winnerName'];
        return GameResult(
          victoryType: victoryType,
          winnerName: winnerName,
        );
      },
    ),


    // 게임 시작 페이지
    GoRoute(path: '/gameMain', builder: (context, state) => GameMain())

    // // case1 : 기본 페이지
    // GoRoute(path: '/', builder: (context, state) => RootPage()),
    // // case2 : page1주소로 이동시 실행 페이지
    // GoRoute(path: '/page1', builder: (context, state) => Page1()),
    // // case3 : page2주소로 이동시 실행 페이지 - 파라미터 포함
    // GoRoute(path: '/page2', builder: (context, state) {
    //   String name = state.uri.queryParameters['name'] ?? '이름 없음';
    //   String age = state.uri.queryParameters['age'] ?? '나이 없음';
    //   return Page2(name: name, age: age);
    // }),
  ],
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
    );
  }
}