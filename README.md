<p align="center">
  <img src="assets/Logo.png" width="400" alt="문화재 마블 로고">
</p>

# 🏯 문화재 마블

> **"주사위로 떠나는 우리 문화유산 여행"**  
> 공공데이터 API와 실시간 통신 기술을 활용한 한국 전통 테마의 보드게임 프로젝트입니다.

---

## 📌 프로젝트 개요
- **개발 기간**: 2025.12.22 ~ 2026.01.08
- **개발 환경**: Flutter (Dart), Firebase, Node.js (Socket.io)
- **핵심 가치**: 실제 문화재 데이터를 활용한 교육적 가치와 실시간 멀티플레이의 재미를 결합

---

## 👥 팀원 소개 및 역할
|                   이름                   | 역할 | 담당 업무                              |            연락처            |
|:--------------------------------------:|:--:|:-----------------------------------|:-------------------------:|
| [**유희연**](https://github.com/hee8144)  | 팀장 | 위젯 , 온라인 게임 기능 구현|   ✉️ zcgy432@gmail.com    |
|  [**정은성**](https://github.com/kkomi211)  | 팀원 | 문화재 api 통합, 비회원 게임 기능 구현, 위젯 통합, 온라인 게임 기능 구현, 봇 기능 구현 |   ✉️ cutybaby8024@gmail.com    |
|  [**조원정**](https://github.com/dragonstudy9)  | 팀원 | 메인 화면, 게임 규칙 설명, 게임 대기방, 게임 결과 화면 구현 | ✉️ dragonstudy9@gmail.com |
| [**이민형**](https://github.com/narang06) | 팀원 | 찬스 카드 및 퀴즈 로직 설계 및 구현 , 로그인 시스템 구현 | ✉️ sinso5281532@gmail.com |

---

## 🖼️ 주요 화면 미리보기

### 1️⃣ 접속 및 멀티플레이 환경 (Auth & Multiplayer)
| **메인 로비 & 로그인** | **온라인 방 목록 및 대기실** |
| :---: | :---: |
| <img src="assets/screenshots/lobby.png" width="400"> | <img width="400" alt="image" src="https://github.com/user-attachments/assets/e52caafb-bea5-4a05-aae6-396d6e0a3bf9" /> |
| *소셜 로그인 기반 통합 세션 및 프로필* | *실시간 소켓 통신을 통한 방 생성 및 입장* |

### 2️⃣ 게임 플레이 및 데이터 연동 (Gameplay & Data)
| **메인 게임 보드** | **특수 이벤트** |
| :---: | :---: |
| <img src="assets/screenshots/gameplay.png" width="400"> | <img src="assets/screenshots/events.png" width="400"> |
| *문화재 API 데이터 기반 실시간 보드 구성* | *교육용 퀴즈 UI* |

---

## ✨ 핵심 기능

### 1. 실시간 멀티플레이 네트워크 엔진 (Online Networking)
- **Socket.io & Node.js 기반 실시간 동기화**: 고성능 소켓 통신을 통해 플레이어 간 위치, 자산 상태, 턴 전환 데이터를 0.1초 단위로 실시간 동기화.
- **동적 방 관리 시스템**: 실시간 방 생성, 대기방 및 플레이어 레디 상태 관리 로직 구축.

### 2. 사용자 인증 및 보안 세션 관리 (Auth & Security)
- **통합 소셜 로그인**: Google, Kakao, Naver 연동 및 자동 로그인으로 사용자 접근성 극대화.
- **멀티 디바이스 세션 제어**: 중복 로그인 방지를 위한 고유 세션 ID 검증 로직을 탑재하여 온라인 대전의 무결성과 계정 보안 확보.

### 3. 하이브리드 게임 모드 (Hybrid Game Mode)
- **실시간 유저 대전 (Online)**: 실시간으로 경쟁하는 소켓 기반의 온라인 모드 지원.
- **AI 대결 및 활동 로그 (Offline)**: 봇(AI)과의 대결 모드를 지원하며, 오프라인 플레이 시 플레이어의 모든 행위를 상세히 기록하는 '장부' 시스템 제공.

### 4. 공공데이터 API 연동 및 게이미피케이션 (Data & Education)
- **문화재청 API 실시간 파싱**: 실제 문화재 데이터를 기반으로 보드를 구성하고, 정규식을 통한 명칭 최적화로 가독성 높은 정보 전달.
- **교육용 퀴즈 시스템**: 문화재 상식 퀴즈 정답 시 통행료 할인 등 보상을 부여하여 교육과 재미를 동시에 잡은 게이미피케이션 구현.

### 5. 실감나는 그래픽 인터랙션 (Graphics)
- **3D 엔진 연출**: Matrix4 렌더링 기반의 3D 주사위 회전 및 찬스카드 아우라 애니메이션으로 시각적 몰입감 증대.
- **반응형 가로 레이아웃**: 와이드 화면에 최적화된 4방향 플레이어 인터페이스 및 상태 기반 다이얼로그 시스템.

---

## 🛠 기술 스택

### **Frontend**
- **Framework**: Flutter (Dart)
- **State Management**: StatefulWidget, Singleton Pattern
- **Navigation**: GoRouter (Dynamic Routing)
- **Graphics**: Matrix4 Perspective, CustomPainter, Flutter Animate

### **Backend & Database**
- **Server**: Node.js (Socket.io)
- **Database**: Firebase Cloud Firestore
- **Auth**: Firebase Authentication & Social Login SDKs

---

## 📂 프로젝트 구조
```text
lib/
├── auth/          # 인증 및 통합 세션 관리 (AuthService, LoginDialog)
├── game/          # 로컬 게임 엔진 및 핵심 로직 (GameMain, HeritageRepo)
│   ├── logic/     # 게임 규칙(인수, 파산 등) 처리 엔진
│   └── widgets/   # 플레이어 패널, 토큰 등 게임 UI 요소
├── network/       # 실시간 서버 통신 모듈 (SocketService)
├── online/        # 멀티플레이어 방 관리 및 온라인 게임 로직
├── Popup/         # 게임 내 팝업 시스템 (상세정보, 건설, 인수 등)
├── quiz/          # 문화재 퀴즈 저장소 및 게이미피케이션 로직
└── widgets/       # 공통 위젯 (LoadingScreen, 통합 애니메이션 등)
```
---
## 📜 발표 PPT

---
[PPT](https://www.canva.com/design/DAG9t7pBUUY/z-FXVDM7JWnX0oS6_LhDgw/edit)
---
## 🎬 시연 영상
[로컬](https://drive.google.com/file/d/11vGx8dul61a5T6oFikvMmwVpiaEQ0uHP/view)<br>
[온라인](https://drive.google.com/file/d/1Qy0P1lHL0tLqrpc49XwjVkyI4wjqEQxu/view?usp=drive_link)
---

## 📂 기타 산출물 링크
---
[서버](https://github.com/hee8144/teamproject_server)
---
© 2026 Cultural Heritage Marble Team. All rights reserved.
