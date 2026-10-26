/// Physical phone pose from the accelerometer, independent of screen rotation lock.
///
/// Android reports gravity as an upward acceleration. With the screen facing
/// the user, +Y points toward the top of the phone and +X points to the right.
int? degreesFromAcceleration(double x, double y) {
  const flat = 6.0;
  if (x.abs() < flat && y.abs() < flat) return null;
  if ((x.abs() - y.abs()).abs() < 1.5) return null;
  if (y.abs() > x.abs()) return y >= 0 ? 0 : 180;
  return x >= 0 ? 90 : 270;
}

bool isLandscapeDegrees(int degrees) => degrees == 90 || degrees == 270;

/// Clockwise JPEG rotation that makes the camera image upright for [deviceDegrees].
int streamAngle({required int sensorOrientation, required int deviceDegrees}) {
  return (sensorOrientation - deviceDegrees + 360) % 360;
}

int deviceDegreesFor({
  required String mode,
  required int sensedDegrees,
  required bool haveSensor,
}) {
  if (mode == 'portrait') return 0;
  if (mode == 'landscape') {
    if (haveSensor && isLandscapeDegrees(sensedDegrees)) return sensedDegrees;
    return 90;
  }
  return haveSensor ? sensedDegrees : 0;
}
