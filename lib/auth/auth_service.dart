import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // 💡 랜덤 닉네임 생성기
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
            'tier': '초보 여행자', // 추후 정식 명칭으로 교체
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
          'tier': '초보 여행자', // 추후 정식 명칭으로 교체
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

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 현재 유저 가져오기
  User? get currentUser => _auth.currentUser;
}