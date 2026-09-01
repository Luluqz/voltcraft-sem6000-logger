// Port of the SEM6000 BLE frame protocol from sem6000.py.
// Reference: https://github.com/Heckie75/voltcraft-sem-6000/blob/master/API.md

const String uuidInfo = "0000fff1-0000-1000-8000-00805f9b34fb";
const String uuidWrite = "0000fff3-0000-1000-8000-00805f9b34fb";
const String uuidNotify = "0000fff4-0000-1000-8000-00805f9b34fb";

const int startByte = 0x0F;
final List<int> endBytes = [0xFF, 0xFF];

int checksum(List<int> payload) {
  final sum = payload.fold<int>(0, (a, b) => a + b);
  return (sum + 1) % 256;
}

List<int> buildFrame(List<int> cmd, [List<int> params = const []]) {
  final payload = [...cmd, ...params];
  final chk = checksum(payload);
  final length = payload.length + 1; // +1: checksum is included in the length
  return [startByte, length, ...payload, chk, ...endBytes];
}

List<int> buildAuthFrame(String pin) {
  if (pin.length != 4 || int.tryParse(pin) == null) {
    throw ArgumentError("PIN must be exactly 4 digits, e.g.: 0000");
  }
  final pinBytes = pin.split('').map(int.parse).toList();
  const cmd = [0x17, 0x00];
  final params = [0x00, ...pinBytes, 0x00, 0x00, 0x00, 0x00];
  return buildFrame(cmd, params);
}

List<int> buildMeasureFrame() {
  const cmd = [0x04, 0x00];
  const params = [0x00, 0x00];
  return buildFrame(cmd, params);
}

int _bytesToIntBigEndian(List<int> bytes) {
  var value = 0;
  for (final b in bytes) {
    value = (value << 8) | b;
  }
  return value;
}

int _bytesToIntLittleEndian(List<int> bytes) {
  var value = 0;
  for (var i = bytes.length - 1; i >= 0; i--) {
    value = (value << 8) | bytes[i];
  }
  return value;
}

class Measurement {
  final bool powerOn;
  final double watts;
  final int voltage;
  final double amperes;
  final int frequency;
  final int totalConsumptionRaw;

  Measurement({
    required this.powerOn,
    required this.watts,
    required this.voltage,
    required this.amperes,
    required this.frequency,
    required this.totalConsumptionRaw,
  });
}

/// Tries to extract power (W), voltage (V), current (A), frequency (Hz)
/// and total consumption from a response frame to the measurement command.
/// Returns null if the frame cannot be decoded.
Measurement? parseMeasurement(List<int> data) {
  try {
    if (data.length < 3 || data[0] != startByte) return null;
    final length = data[1];
    if (data.length < 2 + length) return null;
    final payload = data.sublist(2, 2 + length);
    if (payload.length < 14) return null;

    final cmd = payload.sublist(0, 2);
    if (cmd[0] != 0x04 || cmd[1] != 0x00) return null; // not a measurement response

    final powerOn = payload[2] != 0;
    final wattRaw = _bytesToIntBigEndian(payload.sublist(3, 6));
    final voltage = payload[6];
    final ampereRaw = _bytesToIntBigEndian(payload.sublist(7, 9));
    final frequency = payload[9];
    final totalRaw = _bytesToIntLittleEndian(payload.sublist(10, 14));

    return Measurement(
      powerOn: powerOn,
      watts: wattRaw / 1000.0,
      voltage: voltage,
      amperes: ampereRaw / 1000.0,
      frequency: frequency,
      totalConsumptionRaw: totalRaw,
    );
  } catch (_) {
    return null;
  }
}
