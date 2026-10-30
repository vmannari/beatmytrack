#!/usr/bin/env python3
"""Run an automated command without Windows crash dialogs blocking the desktop.

Usage: python scripts/run_no_crash_dialog.py [--] PROGRAM [ARG ...]

The Windows error mode is inherited only by the launched process and its
descendants. This is for unattended tests, not the interactive editor or game.
Windows Error Reporting may not produce a crash report for these processes.
"""

import ctypes
import os
import subprocess
import sys


def main() -> int:
    command = sys.argv[1:]
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("Usage: run_no_crash_dialog.py [--] PROGRAM [ARG ...]", file=sys.stderr)
        return 2

    if os.name == "nt":
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.GetErrorMode.restype = ctypes.c_uint
        kernel32.SetErrorMode.argtypes = (ctypes.c_uint,)
        kernel32.SetErrorMode.restype = ctypes.c_uint
        # Preserve inherited flags; do not change any machine-wide setting.
        kernel32.SetErrorMode(kernel32.GetErrorMode() | 0x0002)

    try:
        result = subprocess.run(command, check=False)
    except OSError as error:
        print(f"Could not start {command[0]!r}: {error}", file=sys.stderr)
        return 127

    code = result.returncode
    if os.name == "nt" and code & 0x80000000:
        print(f"Command failed with Windows status 0x{code & 0xffffffff:08X}", file=sys.stderr)
    return code if code >= 0 else 128 - code


if __name__ == "__main__":
    status = main()
    if os.name == "nt" and status > 0x7fffffff:
        # Python's sys.exit converts through a signed C long on Windows and
        # otherwise turns exception statuses such as 0xC0000005 into -1.
        ctypes.WinDLL("kernel32").ExitProcess(ctypes.c_uint(status))
    sys.exit(status)
