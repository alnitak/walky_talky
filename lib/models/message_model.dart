import 'dart:typed_data';

/// Enum that represents the message type.
enum MessageChunkType {
  /// The data is first chunk
  first,

  /// The data is middle chunk
  middle,

  /// The data is last chunk
  last,
}

/// Class that represents the message model
class MessageModel {
  ///
  MessageModel({
    required this.fromIp,
    required this.type,
    required this.data,
  });

  /// The ip address of the device that sent the message.
  final String fromIp;

  /// The type of the message.
  final MessageChunkType type;

  /// The chunks of audio data.
  final Uint8List data;

  Map<String, dynamic> toMap() {
    return {
      'fromIp': fromIp,
      'type': type.index,
      'data': data,
    };
  }
}
