// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Webcam & Screen Saver';

  @override
  String get homeIntro =>
      'A phone left at home sends the camera. On the phone you carry, enter only the home camera IP to watch and to turn home devices on or off.';

  @override
  String get homeWindows =>
      'The same video can run on Windows as a screensaver and as the desktop background. Download the installer from GitHub Releases. IP-only setup works—enter the home camera IP; port and path are added for you.';

  @override
  String get downloadWindows => 'Download the Windows installer';

  @override
  String get about => 'About';

  @override
  String get privacy => 'Privacy policy';

  @override
  String get openPrivacy => 'Open the policy on GitHub';

  @override
  String get homeCamera => 'Home camera';

  @override
  String get homeCameraBody => 'Send this phone’s camera.';

  @override
  String get away => 'Watch away';

  @override
  String get awayBody => 'Watch the home video and control devices.';

  @override
  String get lastRole => 'Last role you used';

  @override
  String get settings => 'Settings';

  @override
  String get cameraSettings => 'Camera settings';

  @override
  String get viewerSettings => 'Viewer settings';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get preparing => 'Preparing';

  @override
  String get stopSending => 'Stop sending';

  @override
  String get startSending => 'Start sending';

  @override
  String get viewerIp => 'Home camera IP';

  @override
  String get viewerIpHelp =>
      'Enter only the IP shown on the home camera phone. The port and video path are added for you.';

  @override
  String get screensaver => 'Screensaver';

  @override
  String get enterIpInSettings => 'Enter the home camera IP in settings.';

  @override
  String get connecting => 'Connecting';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get aboutTitle => 'About this app';

  @override
  String get aboutBody =>
      'Webcam & Screen Saver uses an Android phone left at home as the camera, and the phone you carry as the viewer. Enter only the home camera IP. Port 8787 and the video path are added for you. An upright phone sends a tall picture. A phone on its side sends a wide picture. On and off commands for home devices run on the home phone.';

  @override
  String get aboutWindows =>
      'The Windows program can fill the screen as a screensaver. In its settings, Show as background plays the same video behind the desktop icons. Moving the mouse closes the screensaver. The desktop background stays on. Get the installer from GitHub Releases.';

  @override
  String get privacyBody =>
      'Webcam & Screen Saver does not create a developer account. Video moves only between the home phone and the viewer, over Tailscale or an address you open. The developer server does not store video, accounts, or location history.\n\nCamera permission is used only when this phone is the home camera. Network permission is used to send and receive video. Nearby discovery looks for devices on the same home network.\n\nIf you use Tailscale, sign-in stays in the Tailscale app and follows Tailscale’s policy.\n\nThe GitHub account anyethernet publishes this app.\nPrivacy manager: Kim Judong\nContact: https://github.com/anyethernet';
}
