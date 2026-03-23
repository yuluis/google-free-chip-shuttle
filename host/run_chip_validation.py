#!/usr/bin/env python3
"""ULC chip validation runner.

Usage:
    python run_chip_validation.py --port /dev/ttyUSB0
    python run_chip_validation.py --port /dev/ttyUSB0 --mode lab_extended
    python run_chip_validation.py --port /dev/ttyUSB0 --json results.json
"""

import argparse
import csv
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from ulc_driver import ULCDriver
from ulc_registers import *


def print_header(chip_id: int, chip_rev: int):
    print("=" * 60)
    print("  Universal Learning Chip — Validation Report")
    print("=" * 60)
    print(f"  Chip ID  : 0x{chip_id:08X}")
    print(f"  Revision : 0x{chip_rev:08X}")
    print(f"  Timestamp: {datetime.now(timezone.utc).isoformat()}")
    print("=" * 60)


def print_result(r: dict):
    status = "PASS" if r["pass"] else "FAIL"
    print(f"  [{status}] {r['block_name']} (ID=0x{r['block_id']:02X})")
    if not r["pass"]:
        print(f"         Error: {r.get('error_name', r.get('error', 'unknown'))}")
    if "result0" in r:
        print(f"         R0=0x{r['result0']:08X}  R1=0x{r['result1']:08X}  "
              f"R2=0x{r['result2']:08X}  R3=0x{r['result3']:08X}")


def print_summary(results: list[dict], counters: dict):
    passed = sum(1 for r in results if r["pass"])
    failed = len(results) - passed
    print()
    print("-" * 60)
    print(f"  Results: {passed} passed, {failed} failed, {len(results)} total")
    print(f"  Chip counters — pass: {counters['pass_count']}, "
          f"fail: {counters['fail_count']}, log entries: {counters['log_count']}")
    print("-" * 60)
    if failed == 0:
        print("  ALL TESTS PASSED")
    else:
        print("  FAILURES DETECTED — review results above")
        for r in results:
            if not r["pass"]:
                print(f"    - {r['block_name']}: {r.get('error_name', 'unknown')}")
    print("-" * 60)


def save_json(results: list[dict], counters: dict, chip_id: int, chip_rev: int, path: str):
    report = {
        "chip_id": f"0x{chip_id:08X}",
        "chip_rev": f"0x{chip_rev:08X}",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "counters": counters,
        "results": results,
    }
    Path(path).write_text(json.dumps(report, indent=2))
    print(f"\n  JSON report saved to {path}")


def save_csv(results: list[dict], path: str):
    fieldnames = ["block_id", "block_name", "pass", "error_code", "error_name",
                  "result0", "result1", "result2", "result3"]
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for r in results:
            row = dict(r)
            for key in ["result0", "result1", "result2", "result3"]:
                if key in row:
                    row[key] = f"0x{row[key]:08X}"
            writer.writerow(row)
    print(f"  CSV report saved to {path}")


def main():
    parser = argparse.ArgumentParser(description="ULC Chip Validation Runner")
    parser.add_argument("--port", required=True, help="Serial port (e.g. /dev/ttyUSB0)")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate")
    parser.add_argument("--mode", choices=["safe_auto", "lab_extended", "dangerous"],
                        default="safe_auto", help="Test mode")
    parser.add_argument("--json", metavar="FILE", help="Save JSON report")
    parser.add_argument("--csv", metavar="FILE", help="Save CSV report")
    parser.add_argument("--timeout", type=float, default=5.0,
                        help="Per-block timeout in seconds")
    args = parser.parse_args()

    drv = ULCDriver(args.port, baudrate=args.baud)

    try:
        # Step 1: Identify chip
        chip_id = drv.chip_id()
        chip_rev = drv.chip_rev()
        print_header(chip_id, chip_rev)

        # Step 2: Reset and enable
        drv.reset_test_fabric()
        drv.enable_test_fabric()
        print("\n  Test fabric enabled.\n")

        # Step 3: Run tests based on mode
        results = []

        if args.mode in ("safe_auto", "lab_extended"):
            print("  Running safe test suite...")
            results = drv.run_safe_suite(timeout_per_block=args.timeout)
            for r in results:
                print_result(r)

        if args.mode == "dangerous":
            print("\n  WARNING: Dangerous mode — arming NVM/OTP tests")
            drv.arm_dangerous(True)
            r = drv.run_test(BLK_NVM, timeout_s=args.timeout)
            results.append(r)
            print_result(r)
            drv.arm_dangerous(False)

        # Step 4: Read counters and logs
        counters = drv.read_counters()

        # Step 5: Summary
        print_summary(results, counters)

        # Step 6: Save reports
        if args.json:
            save_json(results, counters, chip_id, chip_rev, args.json)
        if args.csv:
            save_csv(results, args.csv)

    finally:
        drv.close()

    # Exit code
    if any(not r["pass"] for r in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
