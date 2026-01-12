import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String? _socialUid;
  static const String _uidKey = "logged_in_uid";
  static const String _sessionKey = "current_session_id";

  // ================= 통합 UID 및 유저 정보 게터 =================
  User? get currentUser => _auth.currentUser;

  String? get currentUid {
    return _auth.currentUser?.uid ?? _socialUid;
  }

  // ================= 자동 로그인 및 세션 관리 =================
  Future<String?> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString(_uidKey);
    final savedSessionId = prefs.getString(_sessionKey);
    
    if (savedUid != null && savedSessionId != null) {
      final doc = await _fs.collection('members').doc(savedUid).get();
      if (doc.exists) {
        final dbSessionId = doc.data()?['sessionId'];
        if (dbSessionId == savedSessionId) {
          _socialUid = savedUid;
          print("🚀 자동 로그인 및 세션 검증 성공");
          return savedUid;
        }
      }
      print("⚠️ 세션 만료 또는 다른 기기 로그인 감지");
      await _removeUidLocally();
    }
    return null;
  }

  Future<void> _removeUidLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    await prefs.remove(_sessionKey);
  }

  Future<String> _refreshSession(String uid) async {
    final String newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, uid);
    await prefs.setString(_sessionKey, newSessionId);
    return newSessionId;
  }

  Future<bool> isAlreadyLoggedIn(String uid) async {
    final doc = await _fs.collection('members').doc(uid).get();
    return doc.exists && doc.data()?['sessionId'] != null;
  }

  // ================= 공통 유저 처리 로직 =================
  Future<void> _handleSocialUser(String uid, String? email, String provider, {bool force = false}) async {
    _socialUid = uid;
    if (!force && await isAlreadyLoggedIn(uid)) throw Exception("DUPLICATE_LOGIN");

    final String newSession = await _refreshSession(uid);
    final userDoc = await _fs.collection('members').doc(uid).get();
    
    if (!userDoc.exists) {
      final String nickname = await _generateAvailableNickname();
      await _fs.collection('members').doc(uid).set({
        'uid': uid, 'email': email, 'nickname': nickname,
        'point': 0, 'winCount': 0, 'totalGames': 0,
        'provider': provider, 'sessionId': newSession,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _fs.collection('members').doc(uid).update({'sessionId': newSession});
    }
  }

  // ================= 로그인/회원가입 메서드 =================
  Future<String?> signInWithNaver({bool force = false}) async {
    try {
      final result = await FlutterNaverLogin.logIn();
      if (!result.status.toString().contains('loggedIn') || result.account == null) return null;
      final String uid = "naver:${result.account!.id}";
      await _handleSocialUser(uid, result.account!.email, 'naver', force: force);
      return uid;
    } catch (e) {
      if (e.toString().contains("DUPLICATE_LOGIN")) rethrow;
      return null;
    }
  }

  Future<String?> signInWithKakao({bool force = false}) async {
    try {
      if (await kakao.isKakaoTalkInstalled()) {
        try { await kakao.UserApi.instance.loginWithKakaoTalk(); } catch (e) {
          if (e is PlatformException && e.code == 'CANCELED') return null;
          await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }
      final kakaoUser = await kakao.UserApi.instance.me();
      final String uid = "kakao:${kakaoUser.id}";
      await _handleSocialUser(uid, kakaoUser.kakaoAccount?.email, 'kakao', force: force);
      return uid;
    } catch (e) {
      if (e.toString().contains("DUPLICATE_LOGIN")) rethrow;
      return null;
    }
  }

  Future<User?> signInWithGoogle({bool force = false}) async {
    try {
      final UserCredential credential = await _auth.signInWithProvider(GoogleAuthProvider());
      if (credential.user != null) {
        await _handleSocialUser(credential.user!.uid, credential.user!.email, 'google', force: force);
      }
      return credential.user;
    } catch (e) {
      if (e.toString().contains("DUPLICATE_LOGIN")) rethrow;
      throw Exception('구글 로그인 실패: $e');
    }
  }

  Future<User?> signUp(String email, String password, String nickname) async {
    if (!(await isNicknameAvailable(nickname))) throw Exception('이미 사용 중인 닉네임입니다.');
    final UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (credential.user != null) {
      final String newSession = await _refreshSession(credential.user!.uid);
      await _fs.collection('members').doc(credential.user!.uid).set({
        'uid': credential.user!.uid, 'email': email, 'nickname': nickname,
        'point': 0, 'winCount': 0, 'totalGames': 0,
        'sessionId': newSession, 'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return credential.user;
  }

  Future<User?> signIn(String email, String password, {bool force = false}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (credential.user != null) {
      final uid = credential.user!.uid;
      if (!force && await isAlreadyLoggedIn(uid)) {
        await _auth.signOut();
        throw Exception("DUPLICATE_LOGIN");
      }
      final String newSession = await _refreshSession(uid);
      await _fs.collection('members').doc(uid).update({'sessionId': newSession});
    }
    return credential.user;
  }

  // ================= 로그아웃 =================
  Future<void> signOut() async {
    try {
      final uid = currentUid;
      if (uid != null) await _fs.collection('members').doc(uid).update({'sessionId': FieldValue.delete()});
      _socialUid = null;
      await _removeUidLocally();
      await Future.wait([
        kakao.UserApi.instance.logout().catchError((_){}),
        FlutterNaverLogin.logOut().catchError((_){}),
        _auth.signOut(),
      ]);
    } catch (e) { print("로그아웃 에러: $e"); }
  }

  // ================= 유틸리티 =================
  Future<String> _generateAvailableNickname() async {
    String nickname;
    int retry = 0;
    do {
      nickname = _generateRandomNickname();
      retry++;
    } while (!(await isNicknameAvailable(nickname)) && retry < 10);
    return nickname;
  }

  String _generateRandomNickname() {
    final adjs = ["신비로운", "지혜로운", "위대한", "친절한", "행복한", "용감한", "즐거운"];
    final nouns = ["탐험가", "여행자", "방랑자", "정복자", "수호자", "동반자", "구도자"];
    return "${adjs[Random().nextInt(adjs.length)]}_${nouns[Random().nextInt(nouns.length)]}_${Random().nextInt(9000) + 1000}";
  }

  Future<bool> isNicknameAvailable(String nickname) async {
    final result = await _fs.collection('members').where('nickname', isEqualTo: nickname).get();
    return result.docs.isEmpty;
  }

  Future<String> getNickname(String uid) async {
    final doc = await _fs.collection('members').doc(uid).get();
    return doc.exists ? (doc.data()?['nickname'] ?? "여행자") : "여행자";
  }

  static String getTierName(int points) {
    if (points >= 10000) return "전설의 유람객";
    if (points >= 5000) return "일류 탐험가";
    if (points >= 1000) return "숙련된 여행자";
    return "초보 여행자";
  }

  static Color getTierColor(int points) {
    if (points >= 10000) return const Color(0xFFFFD700);
    if (points >= 5000) return const Color(0xFF00E5FF);
    if (points >= 1000) return const Color(0xFF69F0AE);
    return const Color(0xFFD7C0A1);
  }
}