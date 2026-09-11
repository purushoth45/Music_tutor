import 'package:equatable/equatable.dart';

abstract class MidiPracticeState extends Equatable {
  const MidiPracticeState();

  @override
  List<Object?> get props => [];
}

class MidiPracticeInitial extends MidiPracticeState {
  const MidiPracticeInitial();
}

class MidiScanning extends MidiPracticeState {
  const MidiScanning();
}

class MidiConnected extends MidiPracticeState {
  final String deviceName;
  const MidiConnected(this.deviceName);

  @override
  List<Object?> get props => [deviceName];
}

class MidiDisconnected extends MidiPracticeState {
  const MidiDisconnected();
}

class MidiError extends MidiPracticeState {
  final String message;
  const MidiError(this.message);

  @override
  List<Object?> get props => [message];
}
