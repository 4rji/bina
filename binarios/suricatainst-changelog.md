# suricatainst — Changelog & Quick Reference

## Changes Highlights

### 1. Interactive interface selection
- When multiple interfaces are detected, the script now shows a numbered menu to choose from.
- Still accepts an argument (`./suricatainst eth1`) or env var (`IFACE=eth1 ./suricatainst`).
- If only one interface exists (besides `lo`), it is selected automatically.

### 2. Automatic interface configuration in suricata.yaml
- The script now replaces the interface in the `af-packet` section of `/etc/suricata/suricata.yaml` automatically.
- No more manual editing required after installation.

### 3. eve-log verification
- Checks that `eve-log` output is enabled in `suricata.yaml`.
- Uncomments it if it was disabled — required for Filebeat to collect Suricata events.

### 4. Persistent promiscuous mode
- Creates a systemd service (`promisc-<interface>.service`) so promiscuous mode survives reboots.
- Previously, `ip link set promisc on` was lost after restart.

### 5. Improved final output
- Removed the manual "edit suricata.yaml" warning (no longer needed).
- Added config files, logs, and useful commands summary.

---

## Quick Reference (after installation)

```
✅ Suricata installed and running on interface: ens18

── Config files ────────────────────────────────────────
  Main config:      /etc/suricata/suricata.yaml
  Default options:   /etc/default/suricata
  Rules:             /var/lib/suricata/rules/

── Logs ────────────────────────────────────────────────
  Fast log:          /var/log/suricata/fast.log
  EVE JSON:          /var/log/suricata/eve.json

── Useful commands ─────────────────────────────────────
  sudo systemctl status suricata
  sudo systemctl restart suricata
  sudo suricata-update              # update rules
  sudo suricata -T -c /etc/suricata/suricata.yaml  # validate config
  sudo tail -f /var/log/suricata/fast.log
```
