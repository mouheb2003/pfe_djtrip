import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Manages audio/video calls via WebRTC.
/// Signaling (offer/answer/ICE) must be relayed via Socket.io by the screen.
class CallService {
  static const _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _targetUserId;
  bool _disposed = false;

  MediaStream? get localStream => _localStream;
  RTCPeerConnection? get peerConnection => _peerConnection;
  String? get targetUserId => _targetUserId;

  /// Creates a peer connection and retrieves the local media stream (audio only or audio+video).
  Future<void> initPeerConnection({
    required bool withVideo,
    required void Function(dynamic offer) onOfferCreated,
    required void Function(RTCIceCandidate candidate) onIceCandidate,
    required void Function(MediaStream stream) onRemoteStream,
    String? remoteOfferSdp,
    String? remoteOfferType,
  }) async {
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection({
      'iceServers': _iceServers,
    });

    final pc = _peerConnection!;
    pc.onIceCandidate = (candidate) {
      try {
        onIceCandidate(candidate);
      } catch (_) {}
    };

    pc.onTrack = (event) {
      try {
        final streams = event.streams;
        if (streams.isNotEmpty) {
          onRemoteStream(streams.first);
        }
      } catch (_) {}
    };

    pc.onAddStream = (stream) {
      try {
        onRemoteStream(stream);
      } catch (_) {}
    };

    final constraints = {
      'audio': true,
      'video': withVideo
          ? {
              'mandatory': {'minWidth': '640', 'minHeight': '480'},
              'optional': [],
            }
          : false,
    };

    try {
      _localStream = await Helper.openCamera(constraints);
      if (_localStream != null) {
        // Unified Plan: use addTrack instead of addStream
        for (final track in _localStream!.getAudioTracks()) {
          await pc.addTrack(track, _localStream!);
        }
        for (final track in _localStream!.getVideoTracks()) {
          await pc.addTrack(track, _localStream!);
        }
      }
    } catch (e) {
      throw Exception('Cannot access camera/microphone: $e');
    }

    if (remoteOfferSdp != null && remoteOfferType != null) {
      final offer = RTCSessionDescription(remoteOfferSdp, remoteOfferType);
      await pc.setRemoteDescription(offer);
      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);
      try {
        onOfferCreated(answer);
      } catch (_) {}
      return;
    }

    final offer = await pc.createOffer({});
    await pc.setLocalDescription(offer);
    try {
      onOfferCreated(offer);
    } catch (_) {}
  }

  /// Sets the partner's ID (for signaling).
  void setTargetUser(String userId) {
    _targetUserId = userId;
  }

  /// Receives the partner's answer (caller side).
  Future<void> setRemoteAnswer(String sdp, String type) async {
    if (_peerConnection == null || _disposed) return;
    final answer = RTCSessionDescription(sdp, type);
    await _peerConnection!.setRemoteDescription(answer);
  }

  /// Receives the partner's offer (callee side) — already handled in initPeerConnection.
  /// Used if the PC is initialized without an offer and receives it later.
  Future<void> setRemoteOffer(String sdp, String type) async {
    if (_peerConnection == null || _disposed) return;
    final offer = RTCSessionDescription(sdp, type);
    await _peerConnection!.setRemoteDescription(offer);
  }

  /// Adds an ICE candidate received via signaling.
  Future<void> addIceCandidate(Map<String, dynamic> map) async {
    if (_peerConnection == null || _disposed) return;
    final candidate = map['candidate'] as String?;
    final sdpMid = map['sdpMid'] as String?;
    final sdpMLineIndex = map['sdpMLineIndex'] as int?;
    if (candidate == null) return;
    final ice = RTCIceCandidate(
      candidate,
      sdpMid ?? '',
      sdpMLineIndex ?? 0,
    );
    await _peerConnection!.addCandidate(ice);
  }

  /// Mute/unmute the microphone.
  Future<void> setMicrophoneMute(bool mute) async {
    if (_localStream == null) return;
    for (final track in _localStream!.getAudioTracks()) {
      await Helper.setMicrophoneMute(mute, track);
    }
  }

  /// Enable/disable the camera (for video calls).
  Future<void> setVideoEnabled(bool enabled) async {
    if (_localStream == null) return;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = enabled;
    }
  }

  /// Switch between front/rear camera (video only).
  Future<bool> switchCamera() async {
    if (_localStream == null) return false;
    final videoTrack = _localStream!.getVideoTracks().isNotEmpty
        ? _localStream!.getVideoTracks().first
        : null;
    if (videoTrack == null) return false;
    return Helper.switchCamera(videoTrack);
  }

  /// Ends the call and releases all resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;
    _targetUserId = null;
  }
}
