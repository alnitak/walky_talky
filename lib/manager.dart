import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lzstring/lzstring.dart' as lz;
import 'package:walky_talky/network/network.dart';
import 'package:walky_talky/network/ws_client.dart';
import 'package:walky_talky/network/ws_server.dart';

/// Singleton class that manage the websocket server and the connected devices.
interface class Manager {
  Manager._();

  /// Singleton instance.
  static final Manager instance = Manager._();

  /// Websocket server port used.
  static int port = 8181;

  /// Websocket server.
  WebSocketServer? server;

  /// List of devices with a websocket listeninf to the port scanned.
  List<WebSocketClient> connections = [];

  /// List of devices found in the network.
  List<String> devices = [];

  /// Private stream controller for the websocket server.
  late final StreamController<dynamic> _serverStreamController =
      StreamController.broadcast();

  /// Stream for the websocket server.
  Stream<dynamic> get serverStream => _serverStreamController.stream;

  /// Start websocket server, find connected devices and connect to them.
  Future<void> start() async {
    server = WebSocketServer(
      socketStreamCtrl: _serverStreamController,
      port: port,
    );
    await server?.start();
    devices = await Network.findDeviceIps([port]);
  }

  /// Refresh the list of connected devices in this network
  Future<void> refreshDevices() async {
    devices.clear();
    devices = await Network.findDeviceIps([port]);
  }

  /// Connect all the devices in the list
  Future<void> connectDevices() async {
    for (final device in devices) {
      final client = WebSocketClient(url: 'ws://$device:$port/ws');
      if (await client.connect()) {
        connections.add(client);
      } else {
        throw Exception('Failed to connect to $device');
      }
    }
  }

  /// Disconnect all the connected devices
  Future<void> disconnectDevices() async {
    for (final connection in connections) {
      await connection.stop();
    }
  }

  /// Send a message to one of the connected device
  void sendMessageTo(String device, dynamic message) {
    for (final connection in connections) {
      if (connection.url.contains(device)) {
        connection.send(message);
      }
    }
  }

  /// Broadcast a message to all the connected devices
  void sendBroadcastMessage(dynamic message) {
    for (final connection in connections) {
      final l = lz.LZString.compressToBase64Sync(message.toString());
      debugPrint('Sending message: before compression: '
          '${(message as String).length} bytes, '
          'after compression: ${l!.length} bytes');
      connection.send(l);
    }
  }

  /// Stop all the connected devices
  Future<void> stop() async {
    for (final connection in connections) {
      await connection.stop();
    }
  }

  /// Stop the websocket server
  Future<void> stopServer() async {
    await server?.stop();
  }
}
