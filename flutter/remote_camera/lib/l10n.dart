import 'package:flutter/widgets.dart';

import 'app_model.dart';

/// Public Windows installer (direct latest asset) and releases list.
const windowsReleasesUrl = 'https://github.com/anyethernet/screen_saver/releases';
const windowsSetupUrl =
    'https://github.com/anyethernet/screen_saver/releases/latest/download/RemoteCamSaver-Setup.exe';
const privacyPolicyUrl = 'https://anyethernet.github.io/privacy-policy/Webcam_Saver/';

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({required AppModel model, required super.child}) : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

S tr(BuildContext context) => S(AppScope.of(context).language);

/// Runtime strings (English default). Mirrors `lib/l10n/app_en.arb` / `app_ko.arb`.
class S {
  const S(this.language);

  final String language;

  bool get ko => language == 'ko';

  String get appName => ko ? '웹캠 & 화면 보호기' : 'Webcam & Screen Saver';

  String get languageName => ko ? '한국어' : 'English';
  String get languageLabel => ko ? '언어' : 'Language';

  String get homeIntro => ko
      ? '집에 둔 폰이 카메라를 보냅니다. 밖에 있는 폰에서는 집 카메라 IP만 넣으면 영상을 보고, 집 기기를 켜거나 끌 수 있습니다. 밖에서는 집 Wi‑Fi IP가 안 통하니, Tailscale을 같은 계정으로 쓰거나 공유기 포트를 열면 됩니다. Tailscale을 쓰면 집 폰에 나온 100. IP를 넣으세요.'
      : 'A phone left at home sends the camera. On the phone you carry, enter only the home camera IP to watch and to turn home devices on or off. Away from home a Wi‑Fi IP will not work—use Tailscale with the same account, or open a router port. With Tailscale, enter the 100.x IP shown on the home phone.';

  String get homeWindows => ko
      ? '같은 영상은 Windows에서도 화면 보호기와 바탕화면 배경으로 볼 수 있습니다. Windows PC에서 아래 링크로 RemoteCamSaver-Setup.exe를 받은 뒤 실행하세요. IP만 넣어도 됩니다—집 카메라 IP만 입력하면 포트와 경로가 붙습니다.\n$windowsSetupUrl'
      : 'The same video can run on Windows as a screensaver and as the desktop background. On a Windows PC, open the link below to download RemoteCamSaver-Setup.exe, then run it. IP-only setup works—enter the home camera IP; port and path are added for you.\n$windowsSetupUrl';

  String get downloadWindows => ko ? 'Windows 설치 파일 받기' : 'Download the Windows installer';
  String get about => ko ? '설명' : 'About';
  String get privacy => ko ? '개인정보처리방침' : 'Privacy policy';
  String get openPrivacy => ko ? 'GitHub에서 방침 보기' : 'Open the policy on GitHub';

  String get homeCamera => ko ? '집 카메라' : 'Home camera';
  String get homeCameraBody => ko ? '이 폰의 카메라를 보냅니다.' : 'Send this phone’s camera.';
  String get away => ko ? '밖에서 보기' : 'Watch away';
  String get awayBody => ko ? '집 영상을 보고 기기를 조정합니다.' : 'Watch the home video and control devices.';
  String get lastRole => ko ? '지난번에 사용한 역할' : 'Last role you used';

  String get settings => ko ? '설정' : 'Settings';
  String get cameraSettings => ko ? '카메라 설정' : 'Camera settings';
  String get viewerSettings => ko ? '보기 설정' : 'Viewer settings';

  String get preparing => ko ? '준비 중' : 'Preparing';
  String get stopSending => ko ? '송출 중지' : 'Stop sending';
  String get startSending => ko ? '송출 시작' : 'Start sending';
  String sendingPose(bool landscape, bool fixed) {
    final pose = landscape ? (ko ? '가로로 보냅니다' : 'Sending landscape') : (ko ? '세로로 보냅니다' : 'Sending portrait');
    return fixed ? '$pose · ${ko ? '고정' : 'locked'}' : pose;
  }

  String streamingFps(String fps) => ko ? '송출 중 · 초당 $fps장' : 'Streaming · $fps frames per second';
  String get beforeStream => ko ? '송출 전입니다.' : 'Not streaming yet.';
  String get dimNote => ko
      ? '화면은 거의 검게 켜 둡니다. 전원 버튼으로 끄면 이 폰은 카메라를 멈춥니다.'
      : 'The screen stays on, almost black. The power button turns the camera off on most phones.';

  String get cameraIp => ko ? '카메라 IP' : 'Camera IP';
  String get findingAddress => ko ? '주소를 찾는 중입니다.' : 'Looking for an address.';
  String get copyThisIp => ko
      ? '이 IP를 Windows와 밖 폰에 넣으면 됩니다.'
      : 'Enter this IP on Windows and on the phone you carry.';
  String get homeOnlyIp => ko
      ? '집 안에서만 열리는 IP입니다. 밖에서는 Tailscale을 연결하세요.'
      : 'This IP works only at home. Connect Tailscale before you leave.';

  String get needCameraPermission => ko ? '카메라 권한이 필요합니다. 설정에서 허용해 주세요.' : 'Camera permission is required. Allow it in settings.';
  String get foregroundFailed => ko ? '송출 알림을 시작하지 못했습니다.' : 'Could not start the streaming notification.';
  String get noCamera => ko ? '이 폰에서 카메라를 찾지 못했습니다.' : 'This phone has no camera.';
  String get badPort => ko ? '포트는 1부터 65535 사이여야 합니다.' : 'The port must be from 1 to 65535.';
  String get portBusy => ko ? '이 포트는 이미 사용 중입니다. 다른 포트를 입력하세요.' : 'That port is already in use. Choose another.';
  String startFailed(Object error) => ko ? '송출을 시작하지 못했습니다. $error' : 'Could not start streaming. $error';

  String get direction => ko ? '화면 방향' : 'Picture direction';
  String get directionHelp => ko
      ? '폰을 세워 두면 세로로, 옆으로 눕히면 가로로 영상을 보냅니다. 화면 자동 회전이 꺼져 있어도 센서로 구분합니다.'
      : 'Upright sends a tall picture. On its side, it sends a wide picture. The sensor is used even when auto-rotate is off.';
  String get auto => ko ? '자동' : 'Auto';
  String get lockPortrait => ko ? '세로 고정' : 'Lock portrait';
  String get lockLandscape => ko ? '가로 고정' : 'Lock landscape';
  String get connection => ko ? '접속' : 'Connection';
  String get port => ko ? '포트' : 'Port';
  String get restartAfterPort => ko ? '포트를 바꾸면 송출을 다시 시작하세요.' : 'Start streaming again after you change the port.';
  String get token => ko ? '토큰' : 'Token';
  String get emptyTokenWarning => ko
      ? '토큰이 비어 있으면 주소를 아는 누구나 영상을 볼 수 있습니다.'
      : 'With an empty token, anyone who knows the address can watch.';
  String get newToken => ko ? '토큰 새로 만들기' : 'New token';
  String get copyToken => ko ? '토큰 복사' : 'Copy token';
  String get otherIps => ko ? '다른 IP' : 'Other IPs';
  String get noAddressYet => ko ? '아직 주소가 없습니다.' : 'No address yet.';
  String get homeAddress => ko ? '집 주소' : 'Home address';
  String get homeDevices => ko ? '집 기기' : 'Home devices';
  String get deviceHelp => ko
      ? '같은 집 네트워크에서 기기를 찾습니다. 밖 폰은 켜기와 끄기만 요청하고, 이 폰이 실행합니다.'
      : 'Find devices on the home network. The phone away from home only asks. This phone runs the command.';
  String get noOnUrl => ko ? '켜는 주소 없음' : 'No on address';
  String get add => ko ? '추가' : 'Add';
  String finding(bool busy) => busy ? (ko ? '찾는 중' : 'Searching') : (ko ? '주변 기기 찾기' : 'Find nearby devices');
  String get addManually => ko ? '직접 추가' : 'Add manually';
  String get noneFound => ko
      ? '주변에서 기기를 찾지 못했습니다. 주소로 직접 추가할 수 있습니다.'
      : 'No nearby device was found. You can add one by address.';
  String get findFailed => ko ? '기기 찾기를 끝내지 못했습니다.' : 'Device search did not finish.';
  String get batteryNote => ko
      ? '송출을 시작하면 화면이 거의 검게 켜진 채로 유지됩니다. 전원 버튼으로 화면을 끄면 대부분의 폰은 카메라까지 멈춥니다. 전원에 연결하고 배터리 제한을 풀어 주세요.'
      : 'While streaming, the screen stays on and almost black. The power button stops the camera on most phones. Keep the phone plugged in and unrestricted.';
  String get unrestrictBattery => ko ? '배터리 제한 풀기' : 'Unrestrict battery';
  String get needName => ko ? '이름을 입력하세요.' : 'Enter a name.';
  String get needOneUrl => ko ? '켜는 주소나 끄는 주소 중 하나는 필요합니다.' : 'Enter an address for on or for off.';
  String deviceTitle(bool create) => create ? (ko ? '기기 추가' : 'Add device') : (ko ? '기기 수정' : 'Edit device');
  String get name => ko ? '이름' : 'Name';
  String get onUrl => ko ? '켜는 주소' : 'On address';
  String get offUrl => ko ? '끄는 주소' : 'Off address';
  String get cancel => ko ? '취소' : 'Cancel';
  String get save => ko ? '저장' : 'Save';

  String get viewerIp => ko ? '집 카메라 IP' : 'Home camera IP';
  String get viewerIpHelp => ko
      ? '집 카메라 폰에 나온 IP만 넣으면 됩니다. 포트와 영상 경로는 자동으로 붙습니다.'
      : 'Enter only the IP shown on the home camera phone. The port and video path are added for you.';
  String get allowBadCert => ko ? '자체 서명 인증서 허용' : 'Allow a self-signed certificate';
  String get allowBadCertHelp => ko
      ? 'https 주소이고 인증서가 직접 만든 것일 때만 켜세요.'
      : 'Turn this on only for an https address with a certificate you made.';
  String get showToken => ko ? '토큰 표시' : 'Show token';

  String get screensaver => ko ? '화면 보호기' : 'Screensaver';
  String get enterIpInSettings => ko ? '설정에서 집 카메라 IP를 입력하세요.' : 'Enter the home camera IP in settings.';
  String get connecting => ko ? '연결하는 중' : 'Connecting';
  String get enterIp => ko ? 'IP 입력' : 'Enter IP';
  String get connect => ko ? '연결' : 'Connect';
  String get disconnect => ko ? '연결 끊기' : 'Disconnect';
  String get devicesHint => ko
      ? '집 폰에서 기기를 찾으면 여기에서 켜고 끌 수 있습니다.'
      : 'Devices found on the home phone can be turned on and off here.';
  String get turnOn => ko ? '켜기' : 'On';
  String get turnOff => ko ? '끄기' : 'Off';
  String shot(bool landscape) => landscape ? (ko ? '가로' : 'Landscape') : (ko ? '세로' : 'Portrait');
  String commandSent(String name, String action) => ko
      ? '$name ${action == 'on' ? '켜기' : '끄기'} 요청을 보냈습니다.'
      : 'Sent ${action == 'on' ? 'on' : 'off'} to $name.';
  String get tapToClose => ko ? '화면을 누르면 닫힙니다' : 'Tap the screen to close';

  String streamStatus(String code) {
    if (code.startsWith('http:')) {
      final number = code.substring(5);
      return ko ? '서버가 $number 응답을 보냈습니다.' : 'The server returned $number.';
    }
    return switch (code) {
      'connecting' => connecting,
      'live' => ko ? '영상 수신 중' : 'Receiving video',
      'disconnected' => disconnect,
      'reconnecting' => ko ? '영상을 다시 연결하는 중' : 'Reconnecting',
      'token' => ko ? '토큰이 맞지 않습니다.' : 'The token does not match.',
      'empty' => ko ? '주소가 비어 있습니다.' : 'The address is empty.',
      'bad' => ko ? '주소를 확인하세요.' : 'Check the address.',
      _ => ko ? '연결 전' : 'Not connected',
    };
  }

  String get connectFirst => ko ? '먼저 카메라에 연결하세요.' : 'Connect to the camera first.';
  String get deviceNoResponse => ko ? '기기가 응답하지 않았습니다.' : 'The device did not respond.';
  String get deviceRequestFailed => ko ? '기기 요청을 보내지 못했습니다.' : 'Could not send the device request.';

  String get tailscale => 'Tailscale';
  String statusLine(String status) => ko ? '상태: $status' : 'Status: $status';
  String get checking => ko ? '확인하는 중' : 'Checking';
  String get notInstalled => ko ? '설치되지 않음' : 'Not installed';
  String get connected => ko ? '연결됨' : 'Connected';
  String get tailscaleHelp => ko
      ? '안드로이드는 연결 스위치를 Tailscale 앱에서만 바꿉니다. 버튼을 누르면 그 앱이 열리고, 돌아와서 상태를 다시 확인합니다.'
      : 'On Android, only the Tailscale app can change the VPN. The button opens that app. Come back and check again.';
  String get checkAgain => ko ? '다시 확인' : 'Check again';
  String get askTailscaleOn => ko ? 'Tailscale 앱에서 연결을 켜 주세요.' : 'Turn the connection on in the Tailscale app.';
  String get askTailscaleOff => ko
      ? 'Tailscale 앱에서 연결을 꺼 주세요. 다른 앱이 VPN을 끌 수는 없습니다.'
      : 'Turn the connection off in the Tailscale app. Another app cannot switch that VPN off.';
  String get tailscaleStore => ko
      ? 'Play 스토어에서 Tailscale을 설치한 뒤, 집 카메라와 같은 계정으로 로그인하세요.'
      : 'Install Tailscale from the Play Store, then sign in with the same account as the home camera.';
  String get tailscaleMissing => ko ? 'Tailscale 앱을 열지 못했습니다.' : 'Could not open the Tailscale app.';
  String get notifyTitle => appName;
  String get notifyText => ko ? '카메라 송출 중' : 'Camera is streaming';
  String copied(String label) => ko ? '$label 복사했습니다.' : 'Copied $label.';

  String get aboutTitle => ko ? '이 앱' : 'About this app';
  String get aboutBody => ko
      ? '웹캠 & 화면 보호기는 집에 남은 안드로이드 폰을 카메라로 쓰고, 밖에 있는 내 폰에서 그 영상을 봅니다. 집 카메라 IP만 넣으면 포트 8787과 영상 경로가 붙습니다. 폰을 세우면 세로, 옆으로 눕히면 가로로 맞춰집니다. 집 안 기기의 켜기와 끄기는 집 폰이 실행합니다. 밖에서 볼 때는 Tailscale을 같은 계정으로 쓰는 것이 가장 쉽고, 공유기 포트포워딩으로도 됩니다.'
      : 'Webcam & Screen Saver uses an Android phone left at home as the camera, and the phone you carry as the viewer. Enter only the home camera IP. Port 8787 and the video path are added for you. An upright phone sends a tall picture. A phone on its side sends a wide picture. On and off commands for home devices run on the home phone. Away from home, Tailscale with the same account is the easiest option; router port forwarding also works.';
  String get aboutWindows => ko
      ? 'Windows용 프로그램은 화면 보호기로 영상을 전체 화면에 띄우고, 설정에서 배경으로 보기를 누르면 바탕화면 아이콘 뒤에서도 같은 영상을 보여 줍니다. 마우스를 움직이면 화면 보호기는 꺼지고, 바탕화면 배경은 켜 둔 채로 남습니다. Windows PC에서 아래 링크로 설치 파일을 받은 뒤 RemoteCamSaver-Setup.exe를 실행하세요.\n$windowsSetupUrl'
      : 'The Windows program can fill the screen as a screensaver. In its settings, Show as background plays the same video behind the desktop icons. Moving the mouse closes the screensaver. The desktop background stays on. On a Windows PC, download the installer from the link below and run RemoteCamSaver-Setup.exe.\n$windowsSetupUrl';

  String get privacyBody => ko
      ? '웹캠 & 화면 보호기는 개발사 계정을 만들지 않습니다. 영상은 Tailscale 또는 사용자가 연 주소로 집 폰과 보는 폰 사이에서만 이동합니다. 개발사 서버에 영상, 계정, 위치 기록을 저장하지 않습니다.\n\n카메라 권한은 이 폰을 집 카메라로 쓸 때만 사용합니다. 네트워크 권한은 영상을 보내고 받는 데 사용합니다. 근처 기기 찾기는 같은 집 네트워크의 기기를 찾는 데 사용합니다.\n\nTailscale을 쓰면 로그인과 연결은 Tailscale 앱의 계정으로 이루어집니다.\n\nGitHub 계정 anyethernet이 이 앱을 게시합니다.\n개인정보 처리 관리자: Kim Judong\n문의: https://github.com/anyethernet'
      : 'Webcam & Screen Saver does not create a developer account. Video moves only between the home phone and the viewer, over Tailscale or an address you open. The developer server does not store video, accounts, or location history.\n\nCamera permission is used only when this phone is the home camera. Network permission is used to send and receive video. Nearby discovery looks for devices on the same home network.\n\nIf you use Tailscale, sign-in stays in the Tailscale app and follows Tailscale’s policy.\n\nThe GitHub account anyethernet publishes this app.\nPrivacy manager: Kim Judong\nContact: https://github.com/anyethernet';

  String knownError(String message) {
    if (!ko) {
      return switch (message) {
        'connect-first' => connectFirst,
        'device-no-response' => deviceNoResponse,
        'device-request-failed' => deviceRequestFailed,
        'empty' => 'The address is empty.',
        'bad' => 'Check the address.',
        _ => message,
      };
    }
    return switch (message) {
      'connect-first' => connectFirst,
      'device-no-response' => deviceNoResponse,
      'device-request-failed' => deviceRequestFailed,
      'empty' => '주소가 비어 있습니다.',
      'bad' => '주소를 확인하세요.',
      'The token does not match.' => streamStatus('token'),
      'That address does not exist.' => '없는 주소입니다.',
      'The request is too long.' => '요청이 너무 깁니다.',
      'Check the request.' => '요청을 확인하세요.',
      'The action must be on or off.' => '동작은 켜기 또는 끄기만 됩니다.',
      'That device does not exist.' => '없는 기기입니다.',
      'This action has no address.' => '이 동작의 주소가 비어 있습니다.',
      'The device address is not valid.' => '기기 주소가 올바르지 않습니다.',
      'The device address must be http or https.' => '기기 주소는 http 또는 https여야 합니다.',
      'The device did not respond.' => '기기가 응답하지 않습니다.',
      'Could not reach the device.' => '기기에 연결하지 못했습니다.',
      'The device list is not valid.' => '기기 목록이 아닙니다.',
      _ => message.startsWith('The device returned ')
          ? '기기가 ${message.substring('The device returned '.length)}'
          : message,
    };
  }
}
