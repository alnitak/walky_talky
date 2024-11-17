import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Class that manage the websocket client
class WebSocketClient {
  ///
  WebSocketClient({required this.url});

  /// The url of the websocket server to connect to.
  final String url;

  /// The websocket client.
  WebSocketChannel? channel;

  /// Connect to the websocket server
  Future<bool> connect() async {
    channel = WebSocketChannel.connect(Uri.parse(url));

    /// Wait for the websocket to be ready
    try {
      await channel?.ready;
      debugPrint('Connected to server! $url');
    } on SocketException catch (e) {
      debugPrint(e.toString());
      return false;
    } on WebSocketChannelException catch (e) {
      debugPrint(e.toString());
      return false;
    }
    return true;
  }

  /// Send a message to the websocket server.
  void send(dynamic message) {
    if (channel == null) {
      throw Exception('Not connected to server');
    }
    debugPrint('Sending message of type: ${message.runtimeType}');
    channel!.sink.add(message);
  }

  /// Get the stream of the websocket server.
  Stream<dynamic> get stream {
    if (channel == null) {
      throw Exception('Not connected to server');
    }
    return channel!.stream;
  }

  /// Stop the websocket client.
  Future<void> stop() async {
    await channel?.sink.close();
  }
}
