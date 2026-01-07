import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // 소셜 로그인(Firebase 미연동) 유저를 위한 UID 저장용
  String? _socialUid;

  // 네이버 로그인
  Future<String?> signInWithNaver() async {
    try {
      final result = await FlutterNaverLogin.logIn();

      if (result.status.toString().contains('loggedIn')) {
        final acc = result.account;
        if (acc == null) return null;

        final String uid = "naver:${acc.id}";
        _socialUid = uid; // UID 저장
        final String? email = acc.email;

        // Firestore 유저 확인 및 생성
        final userDoc = await _fs.collection('members').doc(uid).get();
        if (!userDoc.exists) {
          String uniqueNick = _generateRandomNickname();
          int retryCount = 0;
          while (!(await isNicknameAvailable(uniqueNick)) && retryCount < 10) {
            uniqueNick = _generateRandomNickname();
            retryCount++;
          }

          await _fs.collection('members').doc(uid).set({
            'uid': uid,
            'email': email,
            'nickname': uniqueNick,
            'point': 0,
            'winCount': 0,
            'totalGames': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'provider': 'naver',
          });
        }
        return uid;

      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }


  // 카카오 로그인
  Future<String?> signInWithKakao() async {
    try {
      // 1. 카카오톡 설치 여부 확인
      bool isInstalled = await kakao.isKakaoTalkInstalled();

      if (isInstalled) {
        try {
          await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is kakao.KakaoAuthException && error.error == 'access_denied') return null;
          if (error is PlatformException && error.code == 'CANCELED') return null;
          await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 2. 카카오 사용자 정보 가져오기
      kakao.User kakaoUser = await kakao.UserApi.instance.me();
      
      // 3. UID 생성
      final String uid = "kakao:${kakaoUser.id}";
      _socialUid = uid; // UID 저장
      final String? email = kakaoUser.kakaoAccount?.email;

      // Firestore 유저 확인 및 생성
      final userDoc = await _fs.collection('members').doc(uid).get();
      if (!userDoc.exists) {
        String uniqueNick = _generateRandomNickname();
        int retryCount = 0;
        while (!(await isNicknameAvailable(uniqueNick)) && retryCount < 10) {
          uniqueNick = _generateRandomNickname();
          retryCount++;
        }

        await _fs.collection('members').doc(uid).set({
          'uid': uid,
          'email': email,
          'nickname': uniqueNick,
          'point': 0,
          'winCount': 0,
          'totalGames': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'kakao',
        });
      }

      return uid;
    } catch (e) {
      print('카카오 로그인 에러: $e');
      return null;
    }
  }

  // 랜덤 닉네임 생성기
  String _generateRandomNickname() {
    final adjs = ["신비로운", "지혜로운", "위대한", "친절한", "행복한", "용감한", "즐거운"];
    final nouns = ["탐험가", "여행자", "방랑자", "정복자", "수호자", "동반자", "구도자"];
    final rand = Random().nextInt(9000) + 1000;
    return "${adjs[Random().nextInt(adjs.length)]}_${nouns[Random().nextInt(nouns.length)]}_$rand";
  }

  // 구글 로그인
  Future<User?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final UserCredential userCredential = await _auth.signInWithProvider(googleProvider);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await _fs.collection('members').doc(user.uid).get();
        
        //  신규 유저인 경우에만 닉네임 생성 로직 실행
        if (!userDoc.exists) {
          // 중복 없는 닉네임 찾기 (최대 10번 재시도)
          String uniqueNick = _generateRandomNickname();
          int retryCount = 0;
          while (!(await isNicknameAvailable(uniqueNick)) && retryCount < 10) {
            uniqueNick = _generateRandomNickname();
            retryCount++;
          }

          await _fs.collection('members').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'nickname': uniqueNick, // 중복 확인된 닉네임
            'point': 0,
            'winCount': 0,
            'totalGames': 0,
            'provider': 'google',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return user;
    } catch (e) {
      print("Google Login Error: $e");
      throw Exception('구글 로그인 실패: $e');
    }
  }

  // 닉네임 중복 확인
  Future<bool> isNicknameAvailable(String nickname) async {
    final result = await _fs.collection('members')
        .where('nickname', isEqualTo: nickname)
        .get();
    return result.docs.isEmpty;
  }

  // 회원가입 (이메일/비번)
  Future<User?> signUp(String email, String password, String nickname) async {
    try {
      final bool available = await isNicknameAvailable(nickname);
      if (!available) throw Exception('이미 사용 중인 닉네임입니다.');

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _fs.collection('members').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'nickname': nickname,
          'point': 0,
          'winCount': 0,
          'totalGames': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') throw Exception('비밀번호가 너무 약합니다 (6자 이상).');
      if (e.code == 'email-already-in-use') throw Exception('이미 가입된 이메일입니다.');
      throw Exception(e.message ?? '회원가입 실패');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 로그인 (이메일/비번)
  Future<User?> signIn(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') throw Exception('가입되지 않은 이메일입니다.');
      if (e.code == 'wrong-password') throw Exception('비밀번호가 틀렸습니다.');
      throw Exception(e.message ?? '로그인 실패');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 로그아웃 (통합 버전)
  Future<void> signOut() async {
    try {
      _socialUid = null; // UID 초기화
      // 1. 카카오 로그아웃
      try {
        await kakao.UserApi.instance.logout();
      } catch (e) {
        print("카카오 로그아웃 에러(무시 가능): $e");
      }

      // 2. 네이버 로그아웃
      try {
        await FlutterNaverLogin.logOut();
      } catch (e) {
        print("네이버 로그아웃 에러(무시 가능): $e");
      }

      // 3. Firebase 로그아웃
      await _auth.signOut();
    } catch (e) {
      print("로그아웃 도중 에러 발생: $e");
    }
  }

  // 현재 유저 가져오기
  User? get currentUser => _auth.currentUser;

  // 현재 유저의 실제 UID 가져오기 (Firebase 또는 소셜 전용)
  String? get currentUid {
    if (_auth.currentUser != null) return _auth.currentUser!.uid;
    return _socialUid;
  }

  // 닉네임 가져오기 추가
  Future<String> getNickname(String uid) async {
    try {
      final doc = await _fs.collection('members').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['nickname'] ?? "여행자";
      }
    } catch (e) {
      print("닉네임 조회 에러: $e");
    }
    return "여행자";
  }

  // 포인트별 티어 계산 로직
  static String getTierName(int points) {
    if (points >= 5000) return "전설의 유람객";
    if (points >= 3000) return "일류 탐험가";
    if (points >= 1000) return "숙련된 여행자";
    return "초보 여행자";
  }

  // 티어별 색상 반환 로직
  static Color getTierColor(int points) {
    if (points >= 5000) return const Color(0xFFFFD700); // 전설: 골드
    if (points >= 3000) return const Color(0xFF00E5FF);  // 일류: 하늘색
    if (points >= 1000) return const Color(0xFF69F0AE);  // 숙련: 그린
    return const Color(0xFFD7C0A1); // 초보: 베이지/브론즈
  }

}