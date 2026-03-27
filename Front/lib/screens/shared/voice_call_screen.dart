import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../services/call_service.dart';
import '../../services/auth_service.dart';
import '../../services/call_sound_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String partnerId;
  final String name;
  final String avatarUrl;
  final String subtitle;
  /// true = we are the caller, false = we are the callee
  final bool isInitiator;
  /// Shared socket for signaling (must be connected).
  final io.Socket? socket;
  /// Offer received (callee only): { 'sdp': ..., 'type': 'offer' }
  final Map<String, dynamic>? initialOffer;

  const VoiceCallScreen({
    super.key,
    required this.partnerId,
    required this.name,
    this.avatarUrl = '',
    this.subtitle = '',
    this.isInitiator = true,
    this.socket,
    this.initialOffer,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Duration _callDuration = Duration.zero;
  late final Ticker _ticker;
  final CallService _callService = CallService();
  bool _isConnecting = true;
  bool _isRinging = false;
  String? _error;
  bool _muted = false;
  bool _speakerOn = true;

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

      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _error = 'Autorisation micro requise pour l\'appel.';
          _isConnecting = false;
        });
        return;
      }

      _callService.setTargetUser(widget.partnerId);
      final myId = await AuthService.getUserId();
      if (myId == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Session invalide';
          _isConnecting = false;
        });
        return;
      }

      void sendOffer(dynamic desc) {
        try {
          final map = desc is Map ? desc : (desc.toMap() as Map<String, dynamic>);
      if (widget.isInitiator) {
        socket.emit('call:start', {
          'calleeId': widget.partnerId,
          'type': 'audio',
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
        withVideo: false,
        onOfferCreated: sendOffer,
        onIceCandidate: onIce,
        onRemoteStream: (_) {
          if (!mounted) return;
          setState(() {
            _isConnecting = false;
            _isRinging = false;
          });
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
    await _callService.dispose();
    if (mounted) Navigator.pop(context, 'hangup');
  }

  @override
  void dispose() {
    CallSoundService.stop();
    _ticker.dispose();
    _callService.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final m = _callDuration.inMinutes.toString().padLeft(2, '0');
    final s = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m : $s';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF5B5742),
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
      backgroundColor: const Color(0xFF5B5742),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRinging ? Icons.phone_in_talk : Icons.circle,
                    color: _isRinging ? Colors.orange : const Color(0xFF22C55E),
                    size: 12,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnecting
                        ? 'Connexion...'
                        : _isRinging
                            ? 'En attente...'
                            : 'IN CALL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 70,
              backgroundColor: const Color(0xFFBFA16A),
              backgroundImage: widget.avatarUrl.isNotEmpty
                  ? NetworkImage(widget.avatarUrl)
                  : null,
              child: widget.avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 70, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.subtitle,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              _timerLabel,
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Unmute' : 'Mute',
                    onTap: () async {
                      _muted = !_muted;
                      await _callService.setMicrophoneMute(_muted);
                      if (mounted) setState(() {});
                    },
                  ),
                  _CallButton(
                    icon: Icons.dialpad,
                    label: 'Keypad',
                    onTap: () {},
                  ),
                  _CallButton(
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                    label: 'Speaker',
                    onTap: () {
                      setState(() => _speakerOn = !_speakerOn);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: GestureDetector(
                onTap: _hangUp,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ],
        ),
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
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
