class MidiDeviceItem {
  final String id;
  final String name;
  final String manufacturer;
  final String connectionType;
  final bool isPhysicalUsb;

  const MidiDeviceItem({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.connectionType,
    this.isPhysicalUsb = true,
  });
}
