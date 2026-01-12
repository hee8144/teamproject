import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

// 페이지 import
import 'package:teamproject/online/onlineGameMain.dart';
import 'package:teamproject/online/onlineWatingRoom.dart';
import 'package:teamproject/online/onlineMain.dart';
import 'online/onlineRoomList.dart'; // 닉네임 받는 페이지
import 'online/OnlineGameResult.dart';

import '../firebase_options.dart';
import 'game/gameMain.dart';
import 'main/login.dart';
import 'main/mainUI.dart';
import 'main/game_rule.dart';
import 'main/game_waiting_room.dart';
import 'main/game_result.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']);

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
    GoRoute(
      path: '/onlineGameResult',
      builder: (context, state) {
        final roomId = state.uri.queryParameters['roomId'] ?? '';
        final victoryType = state.uri.queryParameters['victoryType'] ?? 'unknown';
        final winnerIndex = state.uri.queryParameters['winnerIndex'] ?? '0';

        return OnlineGameResult(
          roomId: roomId,
          victoryType: victoryType,
          winnerIndex: winnerIndex,
        );
      },
    ),
    // ✅ [수정됨] 닉네임을 받아서 OnlineRoomListPage로 전달
    GoRoute(
      path: '/onlineRoom',
      builder: (context, state) {
        // 이전 페이지에서 context.go('/onlineRoom', extra: '내닉네임'); 으로 보낸 값
        final String nickname = state.extra as String? ?? "게스트";
        return OnlineRoomListPage(userNickname: nickname);
      },
    ),

    GoRoute(
      path: '/onlineWaitingRoom/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return OnlineWaitingRoom(roomId: roomId);
      },
    ),

    GoRoute(
      path: '/gameRule',
      builder: (context, state) {
        // extra로 전달된 값 받기 (Map 형태 권장)
        final data = (state.extra as Map<String, dynamic>?) ?? {};
        final String fromPage = data['fromPage'] ?? 'unknown';

        return GameRulePage(fromPage: fromPage); // ✅ GameRulePage에 값 전달
      },
    ),
    GoRoute(path: '/gameWaitingRoom', builder: (context, state) => GameWaitingRoom()),

    GoRoute(
      path: '/gameResult',
      builder: (context, state) {
        final victoryType = state.uri.queryParameters['victoryType'] ?? 'turn_limit';
        final winnerName = state.uri.queryParameters['winnerName'];
        return GameResult(
          victoryType: victoryType,
          winnerName: winnerName,
        );
      },
    ),

    // 게임 시작 페이지
    GoRoute(path: '/gameMain', builder: (context, state) => GameMain()),

    GoRoute(
      path: '/onlinegameMain',
      builder: (context, state) {
        final data = (state.extra as Map<String, dynamic>?) ?? {};
        final String roomId = data['roomId'] ?? '';

        return OnlineGamePage(
          roomId: roomId,
        );
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false, // 디버그 배너 제거 (선택사항)
    );
  }
}