import 'package:flutter_bloc/flutter_bloc.dart';
import 'midi_practice_event.dart';
import 'midi_practice_state.dart';

class MidiPracticeBloc extends Bloc<MidiPracticeEvent, MidiPracticeState> {
  MidiPracticeBloc() : super(const MidiDisconnected()) {
    on<ScanMidiDevicesEvent>(_onScan);
    on<ConnectMidiDeviceEvent>(_onConnect);
    on<DisconnectMidiDeviceEvent>(_onDisconnect);
  }

  Future<void> _onScan(ScanMidiDevicesEvent event, Emitter<MidiPracticeState> emit) async {
    emit(const MidiScanning());
    // Simulate Bluetooth/USB scan
    await Future.delayed(const Duration(milliseconds: 1500));
    emit(const MidiConnected('Yamaha PSR-E373 MIDI'));
  }

  void _onConnect(ConnectMidiDeviceEvent event, Emitter<MidiPracticeState> emit) {
    emit(MidiConnected(event.deviceId));
  }

  void _onDisconnect(DisconnectMidiDeviceEvent event, Emitter<MidiPracticeState> emit) {
    emit(const MidiDisconnected());
  }
}
