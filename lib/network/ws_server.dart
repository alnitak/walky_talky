import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_discovery/network_discovery.dart';

/// Class that manage the websocket server.
class WebSocketServer {
  /// Constructor to initialize the port
  WebSocketServer({
    required this.socketStreamCtrl,
    required this.port,
  });

  /// Port of the server.
  final int port;

  /// Stream controller to send data to the client.
  final StreamController<dynamic> socketStreamCtrl;

  /// The server instance.
  HttpServer? _server;

  /// The socket instance.
  WebSocket? socket;

  /// The local IP address of the server.
  String? localIp;

  /// Get the local IP address of the server
  Future<String> getServerIp() async {
    localIp = await NetworkDiscovery.discoverDeviceIpAddress();
    return localIp!;
  }

  /// Start the WebSocket server
  Future<void> start() async {
    if (_server != null) {
      throw Exception('WebSocket server already started.');
    }
    localIp = await getServerIp();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('WebSocket server started on ws://$localIp:$port');

      _server!.listen((HttpRequest request) async {
        debugPrint('Incoming request received...');
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          handleConnection(socket);
        } else {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('WebSocket connections only.');
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('Failed to start server: $e');
    }
  }

  /// Handle a new WebSocket connection
  void handleConnection(WebSocket socket) {
    debugPrint('New client connected!');

    socket.listen(
      (data) {
        debugPrint('Received data from client of type ${data.runtimeType}');
        // socket.add('Echo: $data'); // Send data back to client
        socketStreamCtrl.add(data);
      },
      onDone: () {
        debugPrint('Client disconnected');
      },
      onError: (dynamic error) {
        debugPrint('Error: $error');
      },
    );
  }

  /// Stop the WebSocket server
  Future<void> stop() async {
    await _server?.close(force: true);
    debugPrint('WebSocket server stopped.');
  }
}
