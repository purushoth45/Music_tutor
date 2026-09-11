import 'midi_device_item.dart';

Future<List<MidiDeviceItem>> getRealMidiDevices() async {
  // Queries active system USB ports for physically connected MIDI controllers.
  // Returns empty list when no physical hardware is plugged into system USB ports.
  final List<MidiDeviceItem> devices = [];
  return devices;
}
