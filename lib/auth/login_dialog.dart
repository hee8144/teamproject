import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class LoginDialog extends StatefulWidget {
  final bool isSignUpMode;
  const LoginDialog({super.key, this.isSignUpMode = false});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  late bool isLoginMode;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    isLoginMode = !widget.isSignUpMode;
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _pwCtrl.dispose(); _nicknameCtrl.dispose();
    super.dispose();
  }

  // 💡 공통 로그인 성공 처리
  Future<void> _handleLoginSuccess(String uid) async {
    if (!mounted) return;
    final nickname = await AuthService.instance.getNickname(uid);
    Fluttertoast.showToast(
      msg: "🏯 $nickname님, 환영합니다!",
      gravity: ToastGravity.TOP,
      backgroundColor: const Color(0xFF5D4037),
      textColor: Colors.white,
    );
    Navigator.pop(context);
    context.go('/onlinemain');
  }

  // 💡 중복 로그인 발생 시 강제 접속 확인 팝업
  void _showForceLoginDialog(Future<dynamic> Function() loginAction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("중복 로그인 확인", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("이미 다른 기기에서 사용 중인 계정입니다.\n기존 기기를 로그아웃시키고 접속할까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => isLoading = true);
              try {
                final result = await loginAction();
                if (result != null) {
                  final uid = result is String ? result : (result as User).uid;
                  await _handleLoginSuccess(uid);
                }
              } catch (e) {
                Fluttertoast.showToast(msg: "로그인 실패");
              } finally {
                if (mounted) setState(() => isLoading = false);
              }
            },
            child: const Text("강제 접속"),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => isLoading = true);
    try {
      final email = _emailCtrl.text.trim();
      final pw = _pwCtrl.text.trim();
      final nick = _nicknameCtrl.text.trim();

      if (email.isEmpty || pw.isEmpty) throw Exception("모든 정보를 입력해주세요.");
      
      // 이메일 정규식 검사
      final emailPattern = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
      if (!emailPattern.hasMatch(email)) throw Exception("올바른 이메일 형식이 아닙니다.");

      if (isLoginMode) {
        try {
          final user = await AuthService.instance.signIn(email, pw);
          if (user != null) await _handleLoginSuccess(user.uid);
        } catch (e) {
          if (e.toString().contains("DUPLICATE_LOGIN")) {
            _showForceLoginDialog(() => AuthService.instance.signIn(email, pw, force: true));
          } else { rethrow; }
        }
      } else {
        if (nick.isEmpty) throw Exception("닉네임을 입력해주세요.");
        final user = await AuthService.instance.signUp(email, pw, nick);
        if (user != null) {
          Fluttertoast.showToast(msg: "회원가입 성공! 이제 로그인해주세요.", backgroundColor: Colors.green);
          setState(() { isLoginMode = true; _pwCtrl.clear(); });
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceAll("Exception: ", ""), gravity: ToastGravity.TOP);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: const Alignment(0, -0.8),
      child: Container(
        width: 350,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5D4037), width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isLoginMode ? "로 그 인" : "회 원 가 입",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
            const SizedBox(height: 6),
            if (!isLoginMode) ...[
              TextField(controller: _nicknameCtrl, decoration: _inputDeco("닉네임", Icons.face)),
              const SizedBox(height: 6),
            ],
            TextField(controller: _emailCtrl, decoration: _inputDeco("이메일 주소", Icons.email), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 6),
            TextField(controller: _pwCtrl, decoration: _inputDeco("비밀번호", Icons.lock), obscureText: true),
            const SizedBox(height: 6),
            isLoading
                ? const SizedBox(height: 34, child: Center(child: CircularProgressIndicator(color: Colors.brown, strokeWidth: 2)))
                : SizedBox(width: double.infinity, height: 32,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037)),
                      onPressed: _submit,
                      child: Text(isLoginMode ? "로그인하기" : "가입하기", style: const TextStyle(color: Colors.white, fontSize: 14)),
                    )),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => setState(() { isLoginMode = !isLoginMode; }),
                  child: Text(isLoginMode ? "가입하기" : "로그인", style: const TextStyle(color: Colors.brown, fontSize: 11)),
                ),
                const Text("|", style: TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(width: 8),
                _socialBtn("assets/google_logo.png", () async {
                  try {
                    final user = await AuthService.instance.signInWithGoogle();
                    if (user != null) await _handleLoginSuccess(user.uid);
                  } catch (e) {
                    if (e.toString().contains("DUPLICATE_LOGIN")) {
                      _showForceLoginDialog(() => AuthService.instance.signInWithGoogle(force: true));
                    } else { Fluttertoast.showToast(msg: "구글 로그인 실패"); }
                  }
                }),
                const SizedBox(width: 8),
                _socialBtn("assets/kakao_logo.png", () async {
                  try {
                    final uid = await AuthService.instance.signInWithKakao();
                    if (uid != null) await _handleLoginSuccess(uid);
                  } catch (e) {
                    if (e.toString().contains("DUPLICATE_LOGIN")) {
                      _showForceLoginDialog(() => AuthService.instance.signInWithKakao(force: true));
                    } else { Fluttertoast.showToast(msg: "카카오 로그인 실패"); }
                  }
                }),
                const SizedBox(width: 8),
                _socialBtn("assets/naver_logo.png", () async {
                  try {
                    final uid = await AuthService.instance.signInWithNaver();
                    if (uid != null) await _handleLoginSuccess(uid);
                  } catch (e) {
                    if (e.toString().contains("DUPLICATE_LOGIN")) {
                      _showForceLoginDialog(() => AuthService.instance.signInWithNaver(force: true));
                    } else { Fluttertoast.showToast(msg: "네이버 로그인 실패"); }
                  }
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialBtn(String img, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(radius: 15, backgroundColor: Colors.transparent,
        child: ClipOval(child: Image.asset(img, width: 30, height: 30, fit: BoxFit.cover))),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      prefixIcon: Icon(icon, color: Colors.brown, size: 18),
      hintText: hint, hintStyle: const TextStyle(fontSize: 12),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }
}
