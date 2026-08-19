# sem6000 — Voltcraft SEM6000 Power Logger

A Python script that connects to a **Voltcraft SEM6000** smart plug over Bluetooth Low Energy (BLE) and logs real-time power measurements to a CSV file.

## What it does

Every few seconds (configurable), it reads and records:

- **Power** (W)
- **Voltage** (V)
- **Current** (A)
- **Frequency** (Hz)
- **Total consumption** (raw counter from the device)

Data is saved to a CSV file with timestamps, ready for analysis in Excel, Python, or any data tool.

## Requirements

- Python 3.10+
- A Voltcraft SEM6000 smart plug
- Bluetooth adapter on your machine
- The `bleak` library:

```
pip install bleak
```

## Usage

### 1. Find your device's MAC address

```
python sem6000.py --scan
```

This scans for nearby Bluetooth devices for 10 seconds and prints their addresses. Your SEM6000 will be flagged in the output.

### 2. Start logging

```
python sem6000.py --address AA:BB:CC:DD:EE:FF --pin 0000 --interval 1 --output measurements.csv
```

| Argument | Description | Default |
|---|---|---|
| `--address` | Bluetooth MAC address of the SEM6000 | *(required)* |
| `--pin` | 4-digit PIN code of the device | `0000` |
| `--interval` | Seconds between measurements | `1` |
| `--output` | Output CSV file path | `sem6000_measurements.csv` |
| `--duration` | Total logging duration in seconds (omit for unlimited) | unlimited |

Press **Ctrl+C** to stop logging at any time.

## Output format

```
timestamp,power_on,watts,voltage,amperes,frequency_hz,total_consumption_raw
2025-01-15T14:32:01,True,45.123,230,0.196,50,18742
2025-01-15T14:32:02,True,45.089,230,0.195,50,18742
...
```

## Notes

- The PIN is `0000` by default unless you changed it in the official SEM6000 app.
- The script works on Windows, Linux, and macOS.
- Protocol based on community reverse-engineering: [Heckie75/voltcraft-sem-6000](https://github.com/Heckie75/voltcraft-sem-6000/blob/master/API.md)
