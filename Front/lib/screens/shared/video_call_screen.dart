import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../services/call_service.dart';
import '../../services/call_sound_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String partnerId;
  final String name;
  final String avatarUrl;
  final bool isInitiator;
  final io.Socket? socket;
  final Map<String, dynamic>? initialOffer;

  const VideoCallScreen({
    super.key,
    required this.partnerId,
    required this.name,
    this.avatarUrl = '',
    this.isInitiator = true,
    this.socket,
    this.initialOffer,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Duration _callDuration = Duration.zero;
  late final Ticker _ticker;
  final CallService _callService = CallService();
  bool _isConnecting = true;
  bool _isRinging = false;
  String? _error;
  bool _muted = false;
  bool _videoEnabled = true;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCall();
    });
  }

  void _onTick(Duration elapsed) {
    if (!_isConnecting && !_isRinging) {
      setState(() => _callDuration = elapsed);
    }
  }

  Future<void> _startCall() async {
    try {
      final socket = widget.socket;
      if (socket == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Pas de connexion au serveur';
          _isConnecting = false;
        });
        return;
      }

      final micOk = await Permission.microphone.request();
      final cameraOk = await Permission.camera.request();
      if (!micOk.isGranted || !cameraOk.isGranted) {
        if (!mounted) return;
        setState(() {
          _error = 'Microphone and camera permissions are required for the video call.';
          _isConnecting = false;
        });
        return;
      }

      _callService.setTargetUser(widget.partnerId);

      void sendOffer(dynamic desc) {
        try {
          final map = desc is Map ? desc : (desc.toMap() as Map<String, dynamic>);
          if (widget.isInitiator) {
            socket.emit('call:start', {
              'calleeId': widget.partnerId,
              'type': 'video',
              'offer': map,
            });
          } else {
            socket.emit('call:answer', {
              'callerId': widget.partnerId,
              'answer': map,
            });
          }
        } catch (_) {}
      }

      void onIce(RTCIceCandidate candidate) {
        try {
          final map = candidate.toMap() as Map<String, dynamic>?;
          if (map != null) {
            socket.emit('call:ice_candidate', {
              'targetUserId': widget.partnerId,
              'candidate': map,
            });
          }
        } catch (_) {}
      }

      try {
        await _callService.initPeerConnection(
          withVideo: true,
          onOfferCreated: sendOffer,
          onIceCandidate: onIce,
          onRemoteStream: (stream) async {
            try {
              final renderer = RTCVideoRenderer();
              await renderer.initialize();
              await renderer.setSrcObject(stream: stream);
              if (!mounted) return;
              _remoteRenderer = renderer;
              setState(() {
                _isConnecting = false;
                _isRinging = false;
              });
            } catch (_) {
              if (mounted) {
                setState(() {
                  _error = 'Error displaying remote video';
                  _isConnecting = false;
                });
              }
            }
          },
          remoteOfferSdp: widget.initialOffer?['sdp'] as String?,
          remoteOfferType: widget.initialOffer?['type'] as String?,
        );
      } catch (e) {
        if (!mounted) return;
        String message = e.toString().replaceFirst('Exception: ', '');
        if (e is MissingPluginException) {
          message = 'WebRTC not available. Stop the app, perform a full rebuild (flutter run) and try again.';
        }
        setState(() {
          _error = message;
          _isConnecting = false;
        });
        return;
      }

      try {
        final localStream = _callService.localStream;
        if (localStream != null) {
          _localRenderer = RTCVideoRenderer();
          await _localRenderer!.initialize();
          await _localRenderer!.setSrcObject(stream: localStream);
        }
      } catch (_) {
        // Vue locale optionnelle, on continue
      }

      if (!mounted) return;
      setState(() => _isConnecting = false);
      if (widget.isInitiator) {
        setState(() => _isRinging = true);
        CallSoundService.playRingback();
      }

      socket.on('call:accepted', (data) {
        CallSoundService.stop();
        try {
          if (!mounted) return;
          final answer = data is Map ? data['answer'] : null;
          if (answer != null && answer is Map) {
            _callService.setRemoteAnswer(
              (answer['sdp'] ?? '') as String,
              (answer['type'] ?? 'answer') as String,
            ).then((_) {
              if (mounted) setState(() => _isRinging = false);
            });
          }
        } catch (_) {}
      });

      socket.on('call:rejected', (_) {
        CallSoundService.stop();
        try {
          if (mounted) Navigator.pop(context, 'rejected');
        } catch (_) {}
      });

      socket.on('call:ended', (_) {
        CallSoundService.stop();
        try {
          if (mounted) Navigator.pop(context, 'ended');
        } catch (_) {}
      });

      socket.on('call:ice', (data) {
        try {
          final candidate = data is Map ? data['candidate'] : null;
          if (candidate is Map) {
            _callService.addIceCandidate(Map<String, dynamic>.from(candidate));
          }
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isConnecting = false;
      });
    }
  }

  Future<void> _hangUp() async {
    CallSoundService.stop();
    widget.socket?.emit('call:hangup', {'targetUserId': widget.partnerId});
    await _localRenderer?.dispose();
    _localRenderer = null;
    await _remoteRenderer?.dispose();
    _remoteRenderer = null;
    await _callService.dispose();
    if (mounted) Navigator.pop(context, 'hangup');
  }

  @override
  void dispose() {
    CallSoundService.stop();
    _ticker.dispose();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _callService.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final m = _callDuration.inMinutes.toString().padLeft(2, '0');
    final s = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _remoteRenderer != null
                ? RTCVideoView(
                    _remoteRenderer!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: Colors.black,
                    child: widget.avatarUrl.isNotEmpty
                        ? Image.network(
                            widget.avatarUrl,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: Icon(
                              Icons.person,
                              size: 120,
                              color: Colors.white24,
                            ),
                          ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _hangUp(),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isRinging ? 'En attente...' : _timerLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_localRenderer != null)
            Positioned(
              top: 100,
              right: 18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 90,
                  height: 120,
                  child: RTCVideoView(
                    _localRenderer!,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: 'MUTE',
                  onTap: () async {
                    _muted = !_muted;
                    await _callService.setMicrophoneMute(_muted);
                    if (mounted) setState(() {});
                  },
                ),
                _CallButton(
                  icon: _videoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: 'VIDEO',
                  onTap: () async {
                    _videoEnabled = !_videoEnabled;
                    await _callService.setVideoEnabled(_videoEnabled);
                    if (mounted) setState(() {});
                  },
                ),
                _CallButton(
                  icon: Icons.flip_camera_android,
                  label: 'FLIP',
                  onTap: () async {
                    await _callService.switchCamera();
                    if (mounted) setState(() {});
                  },
                ),
                _CallButton(
                  icon: Icons.volume_up,
                  label: 'AUDIO',
                  onTap: () {},
                ),
                GestureDetector(
                  onTap: _hangUp,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class Ticker {
  final void Function(Duration) onTick;
  late final Stopwatch _sw;
  late final Timer _timer;

  Ticker(this.onTick) {
    _sw = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      onTick(_sw.elapsed);
    });
  }

  void start() => _sw.start();

  void dispose() {
    _timer.cancel();
    _sw.stop();
  }
}
