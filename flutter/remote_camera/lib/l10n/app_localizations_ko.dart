// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '웹캠 & 화면 보호기';

  @override
  String get homeIntro =>
      '집에 둔 폰이 카메라를 보냅니다. 밖에 있는 폰에서는 집 카메라 IP만 넣으면 영상을 보고, 집 기기를 켜거나 끌 수 있습니다.';

  @override
  String get homeWindows =>
      '같은 영상은 Windows에서도 화면 보호기와 바탕화면 배경으로 볼 수 있습니다. 설치 파일은 GitHub Releases에서 받습니다. IP만 넣어도 됩니다—집 카메라 IP만 입력하면 포트와 경로가 붙습니다.';

  @override
  String get downloadWindows => 'Windows 설치 파일 받기';

  @override
  String get about => '설명';

  @override
  String get privacy => '개인정보처리방침';

  @override
  String get openPrivacy => 'GitHub에서 방침 보기';

  @override
  String get homeCamera => '집 카메라';

  @override
  String get homeCameraBody => '이 폰의 카메라를 보냅니다.';

  @override
  String get away => '밖에서 보기';

  @override
  String get awayBody => '집 영상을 보고 기기를 조정합니다.';

  @override
  String get lastRole => '지난번에 사용한 역할';

  @override
  String get settings => '설정';

  @override
  String get cameraSettings => '카메라 설정';

  @override
  String get viewerSettings => '보기 설정';

  @override
  String get language => '언어';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get preparing => '준비 중';

  @override
  String get stopSending => '송출 중지';

  @override
  String get startSending => '송출 시작';

  @override
  String get viewerIp => '집 카메라 IP';

  @override
  String get viewerIpHelp => '집 카메라 폰에 나온 IP만 넣으면 됩니다. 포트와 영상 경로는 자동으로 붙습니다.';

  @override
  String get screensaver => '화면 보호기';

  @override
  String get enterIpInSettings => '설정에서 집 카메라 IP를 입력하세요.';

  @override
  String get connecting => '연결하는 중';

  @override
  String get connect => '연결';

  @override
  String get disconnect => '연결 끊기';

  @override
  String get aboutTitle => '이 앱';

  @override
  String get aboutBody =>
      '웹캠 & 화면 보호기는 집에 남은 안드로이드 폰을 카메라로 쓰고, 밖에 있는 내 폰에서 그 영상을 봅니다. 집 카메라 IP만 넣으면 포트 8787과 영상 경로가 붙습니다. 폰을 세우면 세로, 옆으로 눕히면 가로로 맞춰집니다. 집 안 기기의 켜기와 끄기는 집 폰이 실행합니다.';

  @override
  String get aboutWindows =>
      'Windows용 프로그램은 화면 보호기로 영상을 전체 화면에 띄우고, 설정에서 배경으로 보기를 누르면 바탕화면 아이콘 뒤에서도 같은 영상을 보여 줍니다. 마우스를 움직이면 화면 보호기는 꺼지고, 바탕화면 배경은 켜 둔 채로 남습니다. 설치 파일은 GitHub Releases에서 받습니다.';

  @override
  String get privacyBody =>
      '웹캠 & 화면 보호기는 개발사 계정을 만들지 않습니다. 영상은 Tailscale 또는 사용자가 연 주소로 집 폰과 보는 폰 사이에서만 이동합니다. 개발사 서버에 영상, 계정, 위치 기록을 저장하지 않습니다.\n\n카메라 권한은 이 폰을 집 카메라로 쓸 때만 사용합니다. 네트워크 권한은 영상을 보내고 받는 데 사용합니다. 근처 기기 찾기는 같은 집 네트워크의 기기를 찾는 데 사용합니다.\n\nTailscale을 쓰면 로그인과 연결은 Tailscale 앱의 계정으로 이루어집니다.\n\nGitHub 계정 anyethernet이 이 앱을 게시합니다.\n개인정보 처리 관리자: Kim Judong\n문의: https://github.com/anyethernet';
}
