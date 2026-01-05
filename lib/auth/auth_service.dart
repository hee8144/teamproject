import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // 💡 닉네임 중복 확인
  Future<bool> isNicknameAvailable(String nickname) async {
    final result = await _fs.collection('members')
        .where('nickname', isEqualTo: nickname)
        .get();
    return result.docs.isEmpty;
  }

  // 1. 회원가입
  Future<User?> signUp(String email, String password, String nickname) async {
    try {
      // 💡 닉네임 중복 체크
      bool available = await isNicknameAvailable(nickname);
      if (!available) throw Exception('이미 사용 중인 닉네임입니다.');

      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _fs.collection('members').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'nickname': nickname,
          'point': 0,
          'totalGames': 0,
          'winCount': 0,
          'tier': '초심자',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') throw Exception('비밀번호가 너무 약합니다 (6자 이상).');
      if (e.code == 'email-already-in-use') throw Exception('이미 가입된 이메일입니다.');
      throw Exception(e.message);
    }
  }

  // 2. 로그인
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') throw Exception('가입되지 않은 이메일입니다.');
      if (e.code == 'wrong-password') throw Exception('비밀번호가 틀렸습니다.');
      throw Exception(e.message);
    }
  }

  // 3. 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
