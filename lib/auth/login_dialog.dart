import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { isLoading = true; });
    try {
      final email = _emailCtrl.text.trim();
      final pw = _pwCtrl.text.trim();
      final nick = _nicknameCtrl.text.trim();

      if (email.isEmpty || pw.isEmpty) throw Exception("모든 정보를 입력해주세요.");
      
      if (!isLoginMode) {
        if (nick.isEmpty) throw Exception("닉네임을 입력해주세요.");
        final passwordPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*[!@#$%^&*(),.?":{}|<>]).{6,}$');
        if (!passwordPattern.hasMatch(pw)) {
          throw Exception("비밀번호는 6자 이상, 영문과 특수문자를 포함해야 합니다.");
        }
      }

      if (isLoginMode) {
        await AuthService.instance.signIn(email, pw);
        if (mounted) {
          Navigator.pop(context);
          context.go('/onlinemain');
        }
      } else {
        await AuthService.instance.signUp(email, pw, nick);
        if (mounted) {
          Fluttertoast.showToast(
            msg: "회원가입 성공! 이제 로그인해주세요.",
            backgroundColor: Colors.green,
            textColor: Colors.white,
            gravity: ToastGravity.TOP,
          );
          setState(() {
            isLoginMode = true;
            _pwCtrl.clear();
            _nicknameCtrl.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: e.toString().replaceAll("Exception: ", ""),
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          gravity: ToastGravity.TOP,
        );
      }
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
            const SizedBox(height: 2),
            Text(
              isLoginMode ? "로 그 인" : "회 원 가 입",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
            ),
            const SizedBox(height: 6),
            if (!isLoginMode) ...[
              TextField(
                controller: _nicknameCtrl,
                decoration: _inputDeco("닉네임", Icons.face),
                keyboardType: TextInputType.text,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 6),
            ],
            TextField(
              controller: _emailCtrl,
              decoration: _inputDeco("이메일 주소", Icons.email),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _pwCtrl,
              decoration: _inputDeco(
                isLoginMode ? "비밀번호" : "비밀번호 (6자 이상, 영문/특수문자 포함)", 
                Icons.lock
              ),
              obscureText: true,
            ),
            const SizedBox(height: 6),
            isLoading
                ? const SizedBox(
                    height: 34,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: CircularProgressIndicator(color: Colors.brown, strokeWidth: 2),
                      ),
                    ),
                  )
                : SizedBox(
                    width: double.infinity, height: 32,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: _submit,
                      child: Text(isLoginMode ? "로그인하기" : "가입하기", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => setState(() { isLoginMode = !isLoginMode; }),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: Text(isLoginMode ? "아직 회원이 아니신가요? 가입하기" : "이미 계정이 있으신가요? 로그인",
                    style: const TextStyle(color: Colors.brown, fontSize: 11)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("|", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ),
                _socialBtn(
                  img: "assets/google_logo.png", 
                  onTap: () async {
                    try {
                      await AuthService.instance.signInWithGoogle();
                      if (mounted) context.go('/onlinemain');
                    } catch (e) {
                      Fluttertoast.showToast(msg: "구글 로그인 실패");
                    }
                  }
                ),
                const SizedBox(width: 8),
                _socialBtn(img: "assets/kakao_logo.png", onTap: () {}),
                const SizedBox(width: 8),
                _socialBtn(img: "assets/naver_logo.png", onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialBtn({required String img, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 15,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: Image.asset(
            img,
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey,
              child: const Icon(Icons.person, size: 10, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
      prefixIcon: Icon(icon, color: Colors.brown, size: 18),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }
}