#!/usr/bin/env python3
# 4rji Decloaking Utility - Version 1.0
# Based on Sandfly Security's file decloaking concept (MIT)

import os
import sys
import mmap
import binascii
from datetime import datetime

VERSION = "1.0"

DEFAULT_TARGETS = [
    "/etc",
    "/var/spool/cron",
    "/etc/cron.d",
    "/etc/cron.daily",
    "/etc/cron.hourly",
    "/etc/cron.weekly",
    "/etc/cron.monthly",
    "/root",
]

DEFAULT_FILES_HINT = [
    "/etc/passwd",
    "/etc/shadow",
    "/etc/group",
    "/etc/ld.so.preload",
    "/etc/modules",
    "/etc/crontab",
    "/etc/ssh/sshd_config",
]

SKIP_DIRS = {"/proc", "/sys", "/dev", "/run"}

def usage():
    print(f"Usage:\n  {sys.argv[0]} [DIRECTORY|FILE]\n\nExamples:\n  {sys.argv[0]}\n  {sys.argv[0]} /etc\n  {sys.argv[0]} ./some_dir\n  {sys.argv[0]} /etc/ld.so.preload\n")
    sys.exit(1)

def make_report_path():
    home = os.path.expanduser("~")
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return os.path.join(home, f"ESCANEO_{ts}.txt")

def explain(report_path):
    print(f"\n4rji Decloaking Utility - Version {VERSION}")
    print("What this does:")
    print("  - Reads files using standard I/O and also via memory-mapped I/O (mmap).")
    print("  - If something is hiding bytes from normal reads, mmap may still reveal them.")
    print("  - Flags files where the total bytes read differ between the two methods.")
    print(f"\nReport file: {report_path}")
    print("\nTargets to scan (default directories):")
    for d in DEFAULT_TARGETS:
        print(f"  - {d}")
    print("\nHigh-value files often worth checking (examples):")
    for f in DEFAULT_FILES_HINT:
        print(f"  - {f}")
    print()

def ask_continue():
    ans = input("Continue? [Y/n]: ").strip().lower()
    if ans in ("", "y", "yes"):
        return True
    if ans in ("n", "no"):
        return False
    return False

def should_skip_path(path):
    ap = os.path.abspath(path)
    for s in SKIP_DIRS:
        if ap == s or ap.startswith(s + os.sep):
            return True
    return False

def read_standard(path):
    total = 0
    try:
        with open(path, "rb") as f:
            for line in f:
                total += len(line)
    except Exception:
        return None
    return total

def read_mmap(path):
    try:
        with open(path, "rb") as f:
            st = os.fstat(f.fileno())
            size = st.st_size
            if size == 0:
                return 0
            mm = mmap.mmap(f.fileno(), 0, access=mmap.PROT_READ)
            try:
                return mm.size()
            finally:
                mm.close()
    except Exception:
        return None

def show_decloak_diff(path, report_fp, show_lines=200):
    hdr = (
        "\n" + "*" * 90 + "\n"
        f"[ALERT] Possible cloaked data in: {path}\n"
        + "*" * 90 + "\n"
    )
    print(hdr, end="")
    report_fp.write(hdr)

    # Standard I/O view
    print("\n--- Standard I/O view (first lines) ---")
    report_fp.write("\n--- Standard I/O view (first lines) ---\n")
    try:
        with open(path, "rb") as f:
            for i, line in enumerate(f):
                if i >= show_lines:
                    print("... (truncated)")
                    report_fp.write("... (truncated)\n")
                    break
                try:
                    s = line.decode("utf-8", errors="strict").rstrip("\n\r")
                    print(s)
                    report_fp.write(s + "\n")
                except UnicodeDecodeError:
                    hx = "hex: " + binascii.hexlify(line).decode()
                    print(hx)
                    report_fp.write(hx + "\n")
    except Exception as e:
        msg = f"(error reading standard I/O: {e})"
        print(msg)
        report_fp.write(msg + "\n")

    # mmap view
    print("\n--- MMAP view (first lines) ---")
    report_fp.write("\n--- MMAP view (first lines) ---\n")
    try:
        with open(path, "rb") as f:
            st = os.fstat(f.fileno())
            size = st.st_size
            if size == 0:
                print("(empty file)")
                report_fp.write("(empty file)\n")
                return
            mm = mmap.mmap(f.fileno(), 0, access=mmap.PROT_READ)
            try:
                seek = 0
                lines = 0
                while seek < mm.size() and lines < show_lines:
                    out = mm.readline()
                    seek += len(out)
                    lines += 1
                    try:
                        s = out.decode("utf-8", errors="strict").rstrip("\n\r")
                        print(s)
                        report_fp.write(s + "\n")
                    except UnicodeDecodeError:
                        hx = "hex: " + binascii.hexlify(out).decode()
                        print(hx)
                        report_fp.write(hx + "\n")
                if seek < mm.size():
                    print("... (truncated)")
                    report_fp.write("... (truncated)\n")
            finally:
                mm.close()
    except Exception as e:
        msg = f"(error reading mmap: {e})"
        print(msg)
        report_fp.write(msg + "\n")

def iter_files(root):
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        if should_skip_path(dirpath):
            dirnames[:] = []
            continue
        dirnames[:] = [d for d in dirnames if not should_skip_path(os.path.join(dirpath, d))]
        for name in filenames:
            p = os.path.join(dirpath, name)
            try:
                st = os.lstat(p)
            except Exception:
                continue
            if not os.path.isfile(p):
                continue
            # skip huge files (tune)
            if st.st_size > 50 * 1024 * 1024:
                continue
            yield p

def scan_path(target, report_fp, suspicious_list):
    suspicious = 0
    scanned = 0
    unreadable = 0

    if os.path.isfile(target):
        paths = [target]
    else:
        paths = iter_files(target)

    for p in paths:
        if should_skip_path(p):
            continue
        std = read_standard(p)
        mm = read_mmap(p)

        if std is None or mm is None:
            unreadable += 1
            continue

        scanned += 1
        if std != mm:
            suspicious += 1
            suspicious_list.append(p)
            show_decloak_diff(p, report_fp)

    return scanned, suspicious, unreadable

def main():
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] in ("-h", "--help")):
        usage()

    report_path = make_report_path()
    os.makedirs(os.path.dirname(report_path), exist_ok=True)

    suspicious_files = []

    with open(report_path, "w", encoding="utf-8", errors="replace") as report_fp:
        explain(report_path)

        target = None
        if len(sys.argv) == 2:
            target = sys.argv[1]
            if not os.path.exists(target):
                print(f"Target does not exist: {target}")
                sys.exit(2)
            print(f"Custom target requested: {target}\n")
            report_fp.write(f"Custom target requested: {target}\n\n")
        else:
            print("No custom target provided; will scan the default directories listed above.\n")
            report_fp.write("No custom target provided; scanning default directories.\n\n")

        if not ask_continue():
            print("Cancelled.")
            report_fp.write("Cancelled by user.\n")
            sys.exit(0)

        total_scanned = 0
        total_suspicious = 0
        total_unreadable = 0

        if target:
            s, sp, u = scan_path(target, report_fp, suspicious_files)
            total_scanned += s
            total_suspicious += sp
            total_unreadable += u
        else:
            for d in DEFAULT_TARGETS:
                if os.path.exists(d):
                    msg = f"\n[+] Scanning: {d}"
                    print(msg)
                    report_fp.write(msg + "\n")
                    s, sp, u = scan_path(d, report_fp, suspicious_files)
                    total_scanned += s
                    total_suspicious += sp
                    total_unreadable += u

        summary = (
            "\n" + "=" * 60 + "\n"
            "Scan summary\n"
            + "=" * 60 + "\n"
            f"Files scanned:     {total_scanned}\n"
            f"Suspicious files:  {total_suspicious}\n"
            f"Unreadable files:  {total_unreadable}\n"
        )
        print(summary, end="")
        report_fp.write(summary)

        if suspicious_files:
            print("Suspicious file list:")
            report_fp.write("Suspicious file list:\n")
            for p in suspicious_files:
                print(f"  - {p}")
                report_fp.write(f"  - {p}\n")
            print("\nALERT: One or more files showed size mismatches (possible cloaked data).")
            report_fp.write("\nALERT: One or more files showed size mismatches (possible cloaked data).\n")
        else:
            print("OK: No size mismatches found (no decloaking evidence in scanned targets).")
            report_fp.write("OK: No size mismatches found (no decloaking evidence in scanned targets).\n")

        print(f"\nSaved report: {report_path}\n")
        report_fp.write(f"\nSaved report: {report_path}\n")

if __name__ == "__main__":
    main()
