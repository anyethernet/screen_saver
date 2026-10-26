import 'package:flutter_test/flutter_test.dart';
import 'package:remote_camera/iot_discover.dart';

void main() {
  test('known device replies become on and off addresses', () {
    final tasmota = describeDevice(
      name: '거실',
      host: '192.168.0.20',
      port: 80,
      tasmotaBody: '{"Status":{"DeviceName":"거실"}}',
    );
    expect(tasmota.kind, 'Tasmota');
    expect(tasmota.onUrl, 'http://192.168.0.20/cm?cmnd=Power%20On');
    expect(tasmota.offUrl, 'http://192.168.0.20/cm?cmnd=Power%20Off');

    final shelly = describeDevice(
      name: '현관',
      host: '192.168.0.21',
      port: 80,
      shellyBody: '{"type":"SHSW-1","gen":2}',
    );
    expect(shelly.kind, 'Shelly');
    expect(shelly.onUrl, contains('on=true'));
    expect(shelly.offUrl, contains('on=false'));
  });
}
