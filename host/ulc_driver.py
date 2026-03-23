"""ULC UART driver — register read/write over serial.

Protocol:
  Write: 'W' (0x57) + addr(1B) + data(4B MSB-first) -> ACK (0x06)
  Read:  'R' (0x52) + addr(1B) -> data(4B MSB-first)
"""

import struct
import time
from typing import Optional

import serial

from ulc_registers import *


class ULCDriver:
    """Low-level UART register access to the ULC chip."""

    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 2.0):
        self.ser = serial.Serial(port, baudrate=baudrate, timeout=timeout)
        self.ser.reset_input_buffer()

    def close(self):
        self.ser.close()

    def write_reg(self, addr: int, data: int):
        """Write a 32-bit register."""
        pkt = bytes([0x57, addr & 0xFF]) + struct.pack(">I", data & 0xFFFFFFFF)
        self.ser.write(pkt)
        ack = self.ser.read(1)
        if len(ack) != 1 or ack[0] != 0x06:
            raise IOError(f"Write ACK failed: got {ack!r}")

    def read_reg(self, addr: int) -> int:
        """Read a 32-bit register."""
        self.ser.write(bytes([0x52, addr & 0xFF]))
        resp = self.ser.read(4)
        if len(resp) != 4:
            raise IOError(f"Read failed: expected 4 bytes, got {len(resp)}")
        return struct.unpack(">I", resp)[0]

    # ----- High-level helpers -----

    def chip_id(self) -> int:
        return self.read_reg(REG_CHIP_ID)

    def chip_rev(self) -> int:
        return self.read_reg(REG_CHIP_REV)

    def enable_test_fabric(self):
        self.write_reg(REG_GLOBAL_CONTROL, 1 << CTRL_GLOBAL_ENABLE)

    def reset_test_fabric(self):
        ctrl = self.read_reg(REG_GLOBAL_CONTROL)
        self.write_reg(REG_GLOBAL_CONTROL, ctrl | (1 << CTRL_RESET_FABRIC))
        time.sleep(0.01)
        self.write_reg(REG_GLOBAL_CONTROL, ctrl & ~(1 << CTRL_RESET_FABRIC))

    def clear_results(self):
        ctrl = self.read_reg(REG_GLOBAL_CONTROL)
        self.write_reg(REG_GLOBAL_CONTROL, ctrl | (1 << CTRL_CLEAR_RESULTS))

    def arm_dangerous(self, arm: bool = True):
        ctrl = self.read_reg(REG_GLOBAL_CONTROL)
        if arm:
            ctrl |= (1 << CTRL_ARM_DANGEROUS)
        else:
            ctrl &= ~(1 << CTRL_ARM_DANGEROUS)
        self.write_reg(REG_GLOBAL_CONTROL, ctrl)

    def run_test(self, block_id: int, timeout_s: float = 5.0) -> dict:
        """Select a block, start its test, poll until done, return results."""
        self.clear_results()
        self.write_reg(REG_BLOCK_SELECT, block_id)
        self.write_reg(REG_COMMAND, CMD_START_SELECTED)

        deadline = time.time() + timeout_s
        while time.time() < deadline:
            status = self.read_reg(REG_GLOBAL_STATUS)
            if status & (1 << STAT_DONE):
                break
            time.sleep(0.01)
        else:
            return {
                "block_id": block_id,
                "block_name": BLOCK_NAMES.get(block_id, f"0x{block_id:02X}"),
                "pass": False,
                "error": "Host-side timeout (chip did not respond)",
                "error_code": 0xFF,
                "status_raw": self.read_reg(REG_GLOBAL_STATUS),
            }

        error_code = self.read_reg(REG_ERROR_CODE) & 0xFF
        return {
            "block_id": block_id,
            "block_name": BLOCK_NAMES.get(block_id, f"0x{block_id:02X}"),
            "pass": bool(status & (1 << STAT_PASS)),
            "fail": bool(status & (1 << STAT_FAIL)),
            "timeout": bool(status & (1 << STAT_TIMEOUT)),
            "error_code": error_code,
            "error_name": ERROR_NAMES.get(error_code, f"Block-specific (0x{error_code:02X})"),
            "result0": self.read_reg(REG_RESULT0),
            "result1": self.read_reg(REG_RESULT1),
            "result2": self.read_reg(REG_RESULT2),
            "result3": self.read_reg(REG_RESULT3),
            "status_raw": status,
        }

    def run_safe_suite(self, timeout_per_block: float = 5.0) -> list[dict]:
        """Run all safe-mode blocks sequentially."""
        results = []
        for blk in SAFE_BLOCKS:
            results.append(self.run_test(blk, timeout_s=timeout_per_block))
        return results

    def read_counters(self) -> dict:
        return {
            "pass_count": self.read_reg(REG_PASS_COUNT),
            "fail_count": self.read_reg(REG_FAIL_COUNT),
            "log_ptr": self.read_reg(REG_LOG_PTR),
            "log_count": self.read_reg(REG_LOG_COUNT),
        }
