import 'midi_device_item.dart';

import 'midi_hardware_service_stub.dart'
    if (dart.library.html) 'midi_hardware_service_web.dart' as impl;

class MidiHardwareService {
  static Future<List<MidiDeviceItem>> scanHardwareDevices() async {
    try {
      return await impl.getRealMidiDevices();
    } catch (_) {
      return [];
    }
  }
}
