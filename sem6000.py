"""
sem6000_logger.py
------------------
Collects measurements (power, voltage, current, frequency) from a
Voltcraft SEM6000 smart plug via Bluetooth Low Energy, and saves them
to a CSV file with timestamps.

Works on Windows, Linux and macOS using the "bleak" library.

Protocol based on community reverse-engineering of the SEM6000:
https://github.com/Heckie75/voltcraft-sem-6000/blob/master/API.md

INSTALLATION (once):
    pip install bleak

USAGE:
    python sem6000.py --address AA:BB:CC:DD:EE:FF --pin 0000 --interval 1 --output measurements.csv

    --address : Bluetooth MAC address of your SEM6000 (see below for how to find it)
    --pin     : device PIN code (0000 by default if never changed)
    --interval: interval between two measurements, in seconds (default: 1)
    --output  : name of the output CSV file

To find the MAC address, first run:
    python sem6000.py --scan
"""

import argparse
import asyncio
import csv
import os
import sys
from datetime import datetime

from bleak import BleakClient, BleakScanner

# BLE characteristic UUIDs for the SEM6000
UUID_INFO = "0000fff1-0000-1000-8000-00805f9b34fb"   # vendor / firmware info
UUID_WRITE = "0000fff3-0000-1000-8000-00805f9b34fb"  # command write
UUID_NOTIFY = "0000fff4-0000-1000-8000-00805f9b34fb" # response notifications

START_BYTE = 0x0F
END_BYTES = b"\xff\xff"


def checksum(payload_bytes: bytes) -> int:
    """Computes the SEM6000 protocol checksum: sum of bytes + 1, modulo 256."""
    return (sum(payload_bytes) + 1) % 256


def build_frame(cmd: bytes, params: bytes = b"") -> bytes:
    """Builds a complete frame to send to the device."""
    payload = cmd + params
    chk = checksum(payload)
    length = len(payload) + 1  # +1 because the checksum is included in the length
    frame = bytes([START_BYTE, length]) + payload + bytes([chk]) + END_BYTES
    return frame


def build_auth_frame(pin: str) -> bytes:
    """Builds the authentication frame with the 4-digit PIN code."""
    if len(pin) != 4 or not pin.isdigit():
        raise ValueError("PIN must be exactly 4 digits, e.g.: 0000")
    pin_bytes = bytes(int(d) for d in pin)  # each digit = one byte
    cmd = bytes([0x17, 0x00])
    params = bytes([0x00]) + pin_bytes + bytes([0x00, 0x00, 0x00, 0x00])
    return build_frame(cmd, params)


def build_measure_frame() -> bytes:
    """Builds the instant measurement request frame."""
    cmd = bytes([0x04, 0x00])
    params = bytes([0x00, 0x00])
    return build_frame(cmd, params)


def parse_measurement(data: bytes):
    """
    Tries to extract power (W), voltage (V), current (A), frequency (Hz)
    and total consumption from a response frame to the measurement command.

    The exact format varies slightly depending on the SEM6000 hardware version;
    this function covers the most common format (hardware >= v3).
    Returns None if the frame cannot be decoded.
    """
    try:
        if len(data) < 3 or data[0] != START_BYTE:
            return None
        length = data[1]
        payload = data[2:2 + length]  # includes the checksum as the last byte
        if len(payload) < 14:
            return None

        cmd = payload[0:2]
        if cmd != bytes([0x04, 0x00]):
            return None  # not a measurement response

        power_on = payload[2]
        watt_raw = int.from_bytes(payload[3:6], byteorder="big")
        voltage = payload[6]
        ampere_raw = int.from_bytes(payload[7:9], byteorder="big")
        frequency = payload[9]
        total_raw = int.from_bytes(payload[10:14], byteorder="little")

        return {
            "power_on": bool(power_on),
            "watts": watt_raw / 1000.0,
            "voltage": voltage,
            "amperes": ampere_raw / 1000.0,
            "frequency": frequency,
            "total_consumption_raw": total_raw,
        }
    except Exception:
        return None


class SEM6000Logger:
    def __init__(self, address: str, pin: str, output_path: str):
        self.address = address
        self.pin = pin
        self.output_path = output_path
        self._notify_queue: asyncio.Queue = asyncio.Queue()
        self._client: BleakClient | None = None

    async def _on_notify(self, _sender, data: bytearray):
        await self._notify_queue.put(bytes(data))

    async def connect_and_auth(self):
        self._client = BleakClient(self.address)
        await self._client.connect()
        await self._client.start_notify(UUID_NOTIFY, self._on_notify)

        # Authenticate with PIN
        auth_frame = build_auth_frame(self.pin)
        await self._client.write_gatt_char(UUID_WRITE, auth_frame, response=False)
        try:
            await asyncio.wait_for(self._notify_queue.get(), timeout=5)
        except asyncio.TimeoutError:
            print("Warning: no response to authentication, continuing anyway.")

    async def read_once(self):
        # Flush old notifications from the queue
        while not self._notify_queue.empty():
            self._notify_queue.get_nowait()

        frame = build_measure_frame()
        await self._client.write_gatt_char(UUID_WRITE, frame, response=False)

        try:
            data = await asyncio.wait_for(self._notify_queue.get(), timeout=3)
        except asyncio.TimeoutError:
            return None

        return parse_measurement(data)

    async def disconnect(self):
        if self._client and self._client.is_connected:
            await self._client.disconnect()

    def ensure_csv_header(self):
        file_exists = os.path.isfile(self.output_path)
        if not file_exists:
            with open(self.output_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow([
                    "timestamp", "power_on", "watts", "voltage",
                    "amperes", "frequency_hz", "total_consumption_raw"
                ])

    def append_row(self, measurement: dict):
        with open(self.output_path, "a", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow([
                datetime.now().isoformat(timespec="seconds"),
                measurement["power_on"],
                measurement["watts"],
                measurement["voltage"],
                measurement["amperes"],
                measurement["frequency"],
                measurement["total_consumption_raw"],
            ])


async def scan_devices():
    print("Scanning for nearby Bluetooth devices (10 seconds)...")
    devices = await BleakScanner.discover(timeout=10.0)
    found_any = False
    for d in devices:
        name = d.name or ""
        marker = " <-- probably your SEM6000" if "sem" in name.lower() or "volcraft" in name.lower() or "voltcraft" in name.lower() else ""
        print(f"  {d.address}   {name}{marker}")
        found_any = True
    if not found_any:
        print("No devices found. Check that Bluetooth is enabled and the plug is powered on.")


async def run_logger(address: str, pin: str, interval: float, output_path: str, duration: float | None):
    logger = SEM6000Logger(address, pin, output_path)
    logger.ensure_csv_header()

    print(f"Connecting to {address} ...")
    await logger.connect_and_auth()
    print("Connected and authenticated. Starting data collection (Ctrl+C to stop).")

    start_time = asyncio.get_event_loop().time()
    try:
        while True:
            measurement = await logger.read_once()
            if measurement is not None:
                logger.append_row(measurement)
                print(
                    f"{datetime.now().strftime('%H:%M:%S')} | "
                    f"{measurement['watts']:.3f} W | "
                    f"{measurement['voltage']} V | "
                    f"{measurement['amperes']:.3f} A | "
                    f"{measurement['frequency']} Hz"
                )
            else:
                print(f"{datetime.now().strftime('%H:%M:%S')} | (no response, retrying)")

            if duration is not None:
                elapsed = asyncio.get_event_loop().time() - start_time
                if elapsed >= duration:
                    break

            await asyncio.sleep(interval)
    except KeyboardInterrupt:
        print("\nStopped by user.")
    finally:
        await logger.disconnect()
        print(f"Disconnected. Data saved to: {output_path}")


def parse_args():
    parser = argparse.ArgumentParser(description="Power consumption logger for Voltcraft SEM6000")
    parser.add_argument("--scan", action="store_true", help="Scan for nearby Bluetooth devices")
    parser.add_argument("--address", type=str, help="MAC address of the SEM6000, e.g.: AA:BB:CC:DD:EE:FF")
    parser.add_argument("--pin", type=str, default="0000", help="4-digit PIN code (default: 0000)")
    parser.add_argument("--interval", type=float, default=1.0, help="Interval between measurements, in seconds")
    parser.add_argument("--output", type=str, default="sem6000_measurements.csv", help="Output CSV file")
    parser.add_argument("--duration", type=float, default=None, help="Total collection duration, in seconds (optional, unlimited by default)")
    return parser.parse_args()


def main():
    args = parse_args()

    if args.scan:
        asyncio.run(scan_devices())
        return

    if not args.address:
        print("Error: --address is required (or use --scan to find it).")
        sys.exit(1)

    asyncio.run(run_logger(args.address, args.pin, args.interval, args.output, args.duration))


if __name__ == "__main__":
    main()