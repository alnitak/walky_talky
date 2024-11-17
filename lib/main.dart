// ignore_for_file: avoid_print, public_member_api_docs
// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:walky_talky/manager.dart';
import 'package:walky_talky/models/message_model.dart';
import 'package:lzstring/lzstring.dart' as lz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final TextEditingController messageTextController;
  late final TextEditingController sendTextController;
  late String thisDevice;
  late String otherDevices;

  final audioStreamChannels = Channels.mono;
  final audioStreamFormat = BufferPcmType.s16le;

  final recorderFormat = PCMFormat.s16le;
  final recorderChannels = RecorderChannels.mono;

  final sampleRate = 11050;

  final soloud = SoLoud.instance;
  final recorder = Recorder.instance;
  AudioSource? audioSource;
  MessageChunkType messageChunkType = MessageChunkType.first;

  @override
  void initState() {
    super.initState();
    messageTextController = TextEditingController(text: '');
    sendTextController = TextEditingController(text: 'Hello World!');
    thisDevice = '';
    otherDevices = '';

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      Permission.microphone.request().isGranted.then((value) async {
        if (!value) {
          await [Permission.microphone].request();
        }
      });
    }

    /// Listen for imcoming data.
    Manager.instance.serverStream.listen(
      (data) {
        debugPrint('Received data from server of type $data}');
        // final decompress = lz.LZString.decompressFromBase64Sync(data as String);
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        final fromIp = msg['fromIp'] as String;
        final type = MessageChunkType.values[msg['type'] as int];

        /// Convert the "data" map value to a Uint8List
        final chunks =
            Uint8List.fromList((msg['data'] as List<dynamic>).cast<int>());

        switch (type) {
          case MessageChunkType.first:
            if (context.mounted) {
              setState(() {
                messageTextController.text = 'Receiving from $fromIp';
              });
            }
            initAudioSource();

            /// A bit of buffering needed before playing the stream.
            if (audioSource != null) {
              soloud
                ..addAudioDataStream(audioSource!, chunks)
                ..play(audioSource!, volume: 4);
            }

          case MessageChunkType.middle:
            if (audioSource != null) {
              soloud.addAudioDataStream(audioSource!, chunks);
              if (context.mounted) {
                setState(() {
                  messageTextController.text = chunks.sublist(0, 10).toString();
                });
              }
            }
          case MessageChunkType.last:
            // disposeAudioSource();
            if (audioSource != null) {
              soloud.setDataIsEnded(audioSource!);
              debugPrint('Data is ended');
              if (context.mounted) {
                setState(() {
                  messageTextController.text = 'Data is ended from $fromIp';
                });
              }
            }
        }
      },
      onDone: () {
        debugPrint('Done');
      },
    );

    /// Listen for microphne data.
    recorder.uint8ListStream.listen((data) {
      final msg = MessageModel(
        fromIp: thisDevice,
        data: data.rawData,
        type: messageChunkType,
      ).toMap();

      final dynamic v = jsonEncode(msg);
      Manager.instance.sendBroadcastMessage(v);

      if (messageChunkType == MessageChunkType.first) {
        messageChunkType = MessageChunkType.middle;
      }
    });

    init();
  }

  @override
  void dispose() {
    messageTextController.dispose();
    sendTextController.dispose();
    soloud.deinit();
    recorder.deinit();
    super.dispose();
  }

  Future<void> init() async {
    /// Initialize the player and the recorder.
    await soloud.init(channels: Channels.mono, sampleRate: sampleRate);
    soloud.filters.echoFilter.activate();
    soloud.filters.echoFilter.delay.value = 0.1;
    soloud.filters.echoFilter.decay.value = 0.2;

    recorder.init(
      format: recorderFormat,
      sampleRate: sampleRate,
      channels: recorderChannels,
    );

    setState(() {});
  }

  void initAudioSource() {
    if (audioSource != null) disposeAudioSource();

    audioSource = soloud.setBufferStream(
      channels: audioStreamChannels,
      pcmFormat: audioStreamFormat,
      sampleRate: sampleRate,
      bufferingTimeNeeds: 0.2,
    );
    debugPrint('Audio source initialized with hash: ${audioSource!.soundHash}');

    audioSource!.allInstancesFinished.listen((data) async {
      await soloud.disposeSource(audioSource!);
      audioSource = null;
    });
  }

  Future<void> disposeAudioSource() async {
    if (audioSource == null) return;

    await soloud.disposeSource(audioSource!);
    audioSource = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!soloud.isInitialized) return const SizedBox.shrink();

    const gap = SizedBox(width: 8, height: 8);

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// START SERVER
              TextButton.icon(
                label: const Text('Start Server'),
                icon: const Icon(Icons.not_started),
                onPressed: () async {
                  await Manager.instance.start();

                  if (context.mounted) {
                    setState(() {
                      thisDevice =
                          'ws://${Manager.instance.server?.localIp}:8181/ws';
                      otherDevices = Manager.instance.devices.join('\n');
                    });
                  }
                },
              ),
              gap,

              /// CONNECT
              TextButton.icon(
                label: const Text('Connect to listed devices'),
                icon: const Icon(Icons.cast_connected),
                onPressed: () async {
                  await Manager.instance.disconnectDevices();
                  await Manager.instance.connectDevices();

                  if (context.mounted) {
                    setState(() {
                      thisDevice =
                          'ws://${Manager.instance.server?.localIp}:8181/ws';
                      otherDevices = Manager.instance.devices.join('\n');
                    });
                  }
                },
              ),
              gap,

              /// REFRESH CONNECTED DEVICES
              TextButton.icon(
                label: const Text('Refresh devices list'),
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await Manager.instance.refreshDevices();

                  if (context.mounted) {
                    setState(() {
                      otherDevices = Manager.instance.devices.join('\n');
                    });
                  }
                },
              ),
              gap,

              Text(
                thisDevice,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              gap,
              Text(
                otherDevices,
                maxLines: 10,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              gap,

              /// send message
              // Row(
              //   mainAxisSize: MainAxisSize.min,
              //   children: [
              //     Flexible(
              //       child: TextField(
              //         controller: sendTextController,
              //       ),
              //     ),
              //     gap,
              //     TextButton.icon(
              //       label: const Text('Send'),
              //       icon: const Icon(Icons.send),
              //       onPressed: () {
              //         // Manager.instance.sendMessage(sendTextController.text);
              //         final f = Uint8List(10);
              //         Manager.instance.sendBroadcastMessage(f);
              //       },
              //     ),
              //   ],
              // ),
              // gap,

              /// Received message
              TextField(
                controller: messageTextController,
                maxLines: 5,
                onSubmitted: (message) {
                  Manager.instance
                      .sendBroadcastMessage('From $thisDevice: $message');
                },
              ),
              gap,

              /// Microphone button
              Listener(
                onPointerDown: (event) async {
                  messageChunkType = MessageChunkType.first;
                  recorder
                    ..start()
                    ..startStreamingData();
                },
                onPointerUp: (event) {
                  messageChunkType = MessageChunkType.last;
                  recorder
                    ..stopStreamingData()
                    ..stop();

                  final msg = MessageModel(
                    fromIp: thisDevice,
                    data: Uint8List.fromList([0]),
                    type: MessageChunkType.last,
                  ).toMap();

                  final dynamic v = jsonEncode(msg);
                  Manager.instance.sendBroadcastMessage(v);
                },
                child: IconButton(
                  iconSize: 64,
                  color: Colors.red,
                  icon: const Icon(Icons.mic),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
