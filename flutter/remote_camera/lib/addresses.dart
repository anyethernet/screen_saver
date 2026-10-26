import 'dart:io';

import 'mjpeg.dart';

Future<List<String>> localIpv4() async {
  final found = <String>[];
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback && !found.contains(address.address)) {
        found.add(address.address);
      }
    }
  }
  found.sort((a, b) {
    final aTail = isTailscaleAddress(a);
    final bTail = isTailscaleAddress(b);
    if (aTail == bTail) return a.compareTo(b);
    return aTail ? -1 : 1;
  });
  return found;
}
