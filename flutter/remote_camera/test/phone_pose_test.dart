import 'package:flutter_test/flutter_test.dart';
import 'package:remote_camera/phone_pose.dart';

void main() {
  test('upright phone is portrait and a side-lying phone is landscape', () {
    expect(degreesFromAcceleration(0, 9.8), 0);
    expect(degreesFromAcceleration(0, -9.8), 180);
    expect(degreesFromAcceleration(9.8, 0), 90);
    expect(degreesFromAcceleration(-9.8, 0), 270);
    expect(isLandscapeDegrees(90), isTrue);
    expect(isLandscapeDegrees(0), isFalse);
  });

  test('a flat or diagonal phone keeps the previous direction', () {
    expect(degreesFromAcceleration(0.2, 0.4), isNull);
    expect(degreesFromAcceleration(7, 6), isNull);
  });

  test('stream rotation follows the phone instead of a fixed portrait angle', () {
    expect(streamAngle(sensorOrientation: 90, deviceDegrees: 0), 90);
    expect(streamAngle(sensorOrientation: 90, deviceDegrees: 90), 0);
    expect(streamAngle(sensorOrientation: 90, deviceDegrees: 270), 180);
  });

  test('locked orientation overrides the sensor', () {
    expect(
      deviceDegreesFor(mode: 'portrait', sensedDegrees: 90, haveSensor: true),
      0,
    );
    expect(
      deviceDegreesFor(mode: 'landscape', sensedDegrees: 0, haveSensor: true),
      90,
    );
    expect(
      deviceDegreesFor(mode: 'landscape', sensedDegrees: 270, haveSensor: true),
      270,
    );
    expect(
      deviceDegreesFor(mode: 'auto', sensedDegrees: 90, haveSensor: true),
      90,
    );
  });
}
