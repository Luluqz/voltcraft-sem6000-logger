# Power Logger for SEM6000 — mobile version (Flutter)

A Flutter mobile app that mirrors `sem6000.py` (the Python script at the
root of this repo): it connects over Bluetooth Low Energy to a Voltcraft
SEM6000 smart plug, shows live measurements, and can record a session to a
CSV file.

Tested and working on Android (OnePlus 6, Android 11) against a physical
SEM6000 plug — see `SETUP_LOG.md` for the full setup log and the bugs found
and fixed along the way. iOS has not been tested on a real device.

## Features

- BLE scan with detection of nearby SEM6000/Voltcraft devices
- Connect and authenticate with the 4-digit PIN
- Live measurements (power, voltage, current, frequency, on/off state),
  refreshed every second as soon as the connection is established
- Power (W) chart over the whole session
- Optional CSV recording, started/stopped on demand independently of the
  live display
- Export/share the CSV (email, messaging apps, Drive, etc.)
- History of past recordings: list, share, delete
- A banner and an "About" dialog reminding users this is an unofficial app

## Requirements

- Flutter SDK (stable)
- Android SDK (platform 34+, build-tools) for the Android target
- An Android device with Bluetooth enabled (BLE doesn't work in an
  emulator — useful only to preview the UI)
- A Voltcraft SEM6000 smart plug

## Running the app

```bash
cd mobile
flutter pub get
flutter devices        # find the ID of the USB-connected device
flutter run -d <device_id>
```

Building a debug APK:

```bash
flutter build apk --debug
```

## Code layout

- `lib/protocol.dart` — direct port of the SEM6000 protocol (checksum,
  frames, parsing) from `sem6000.py`
- `lib/ble/sem6000_ble.dart` — connection, PIN authentication, periodic
  reads via `flutter_blue_plus`
- `lib/csv_logger.dart` — creating, listing and deleting CSV files (in the
  app's private storage)
- `lib/screens/scan_screen.dart` — scanning and picking a device
- `lib/screens/logger_screen.dart` — connection, live measurements, chart,
  start/stop recording, export
- `lib/screens/history_screen.dart` — list of past CSV recordings

## Android permissions

Already declared in `android/app/src/main/AndroidManifest.xml`:
`BLUETOOTH`/`BLUETOOTH_ADMIN`/`ACCESS_FINE_LOCATION` (Android ≤ 11) and
`BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` (Android 12+), plus the
`bluetooth_le` feature declaration. Nothing to add manually.

## iOS

The native `ios/` project has been generated but not tested on a real
device. Before Bluetooth scanning can work on iOS, add this to
`ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to read measurements from the SEM6000 plug.</string>
```

## Where are the CSV files stored?

In the app's private storage (not visible from a regular file manager, nor
from a PC connected over USB without root/debugging access). Use the
"Export" button (measurement screen or history) to share a file or save it
elsewhere (Drive, Files, email...).

## Legal notice / disclaimer

This is an independent, unofficial app, not affiliated with Voltcraft or
Conrad Electronic. "Voltcraft" and "SEM6000" are trademarks of their
respective owners, mentioned only to describe the app's compatibility with
that device. The disclaimer is shown in the app (a banner on the scan
screen plus an "About" dialog, ⓘ icon in the app bar).

Suggested App Store / Play Store listing description:

> Power consumption logger compatible with the Voltcraft SEM6000 smart
> plug (Bluetooth LE). Independent app, not affiliated with
> Voltcraft/Conrad Electronic.

## Known limitations

- No automatic reconnection if the BLE link drops during a session.
- iOS not tested on a real device.
- Tested with a single physical SEM6000 plug; other SEM6000 hardware
  revisions may return a slightly different frame format (see the comment
  in `parseMeasurement`, `protocol.dart`).
- No detailed time-series view beyond the power chart (voltage/current/
  frequency are only shown as instant readings, not plotted over time).

## Protocol

Based on community reverse-engineered documentation:
[Heckie75/voltcraft-sem-6000](https://github.com/Heckie75/voltcraft-sem-6000/blob/master/API.md)

For a detailed log of the environment setup and the bugs found and fixed
during real-device testing, see `SETUP_LOG.md`.
