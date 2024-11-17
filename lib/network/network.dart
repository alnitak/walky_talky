import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:network_discovery/network_discovery.dart';

/// Class that store the ip address of this devices in the network
/// with the chosen open port;
class Network {
  /// Find ip addresses with the given open ports in the local netwrok
  static Future<List<String>> findDeviceIps(List<int> ports) async {
    final localIp = await NetworkDiscovery.discoverDeviceIpAddress();
    final subnet = localIp.substring(0, localIp.lastIndexOf('.'));

    final stream = NetworkDiscovery.discoverMultiplePorts(subnet, ports);
    final completer = Completer<List<String>>();

    final hosts = <NetworkAddress>[];
    stream.listen((NetworkAddress addr) {
      // if (localIp == addr.ip) return;
      hosts.add(addr);
      debugPrint('Found device: ${addr.ip}: ${addr.openPorts}');
    }).onDone(() {
      debugPrint('Finish. Found ${hosts.length} device(s)');
      completer.complete(hosts.map((e) => e.ip).toList());
    });

    return completer.future;
  }
}
