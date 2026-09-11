import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionHandler {
  Future<bool> requestAudioPermission() async {
    final status = await ph.Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> requestMicrophonePermission() async {
    return requestAudioPermission();
  }

  Future<bool> hasAudioPermission() async {
    final status = await ph.Permission.microphone.status;
    return status.isGranted;
  }

  Future<bool> hasMicrophonePermission() async {
    return hasAudioPermission();
  }
}

