import 'package:equatable/equatable.dart';

abstract class MidiPracticeEvent extends Equatable {
  const MidiPracticeEvent();

  @override
  List<Object?> get props => [];
}

class ScanMidiDevicesEvent extends MidiPracticeEvent {
  const ScanMidiDevicesEvent();
}

class ConnectMidiDeviceEvent extends MidiPracticeEvent {
  final String deviceId;
  const ConnectMidiDeviceEvent(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

class DisconnectMidiDeviceEvent extends MidiPracticeEvent {
  const DisconnectMidiDeviceEvent();
}
