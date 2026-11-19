---
name: troubleshoot
description: Use when diagnosing a hardware, network, NAS, server or device fault (blades, NICs, recorders/CCTV, USB drives, BIOS, peripherals) step by step from logs and symptoms.
---

# Methodical troubleshooting

## 1. Pin down the facts first
Before suggesting fixes, make sure you know:
- Exact model, firmware/BIOS version and OS.
- What works vs. what doesn't (a known-good twin is gold: compare against it).
- What changed recently.
- The actual error text or log lines. Ask for them if missing; don't guess from a vague description.

## 2. Read the evidence
- Parse logs the user pastes line by line; quote the line that matters.
- Linux: `dmesg -T | tail -50`, `journalctl -b -p warning`, `lsblk -f`, `lsusb -t`, `ip -br a`.
- Windows: Event Viewer (System), Device Manager, `Get-NetAdapter`, `Get-PnpDevice -Status Error`.
- Appliances (Dahua XVR, blade AMM/CMM, switches): find the log menu, filter by type and time, export it before it rolls over.

## 3. Split the problem in half
Pick the test that rules out the most at once (e.g. "does FC work on the same midplane path?" separates slot vs. NIC). Order steps cheapest/safest first; reseat/reflash/wipe last.

## 4. Each step
- One change at a time, with what result means what ("if X, it's the cable; if Y, it's the port").
- Warn before anything destructive (formatting, flashing, wiping, factory reset) and name the exact device it touches. Ask for `lsblk` before any `dd`/wipe.

## 5. Close out
- State the root cause in one line once found.
- Give a "so it doesn't happen again" note (separate accounts for audit trails, powered USB hub, firmware update, backup).
