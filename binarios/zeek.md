[![logo](img/logos/logo.png)](index.html)

* [Home](index.html)* * [Scripts](scripts.html)
    * [Search](search.html)

# Zeek

## Zeek is a free and open-source network security monitoring tool. It is designed to be a powerful, full-featured framework for network traffic analysis and security monitoring.

### Project Highlights

#### Zeek monitoring project focused on forwarding network telemetry and Suricata alerts from Debian into Security Onion using Filebeat and Logstash.

* Installed Zeek on Debian and prepared the host to collect network protocol logs.
* Configured Filebeat inputs for Zeek logs and Suricata `eve.json` events.
* Forwarded logs to Security Onion Logstash on port 5044 and validated connectivity with
  Filebeat, netcat, and tcpdump.
* Enabled SSH protocol logging and brute-force detection scripts inside Zeek for stronger
  security monitoring coverage.

![Zeek Preview](portfolio/assets/zeek.jpg)

Forwarding Zeek & Suricata to Security Onion (SO 2.4) with Filebeat — Quick Guide

# Forwarding Zeek & Suricata to Security Onion (SO 2.4) with Filebeat

**Contents**

1. [Install Zeek on Debian using this script ONLY](#step0)

   [Download this script](https://raw.githubusercontent.com/4rji/bina/refs/heads/main/binarios/zeekinst)
2. [Install Filebeat on Debian 13 (Trixie)](#step1)
3. [Configure inputs (Suricata & Zeek)](#step2)
4. [Configure Logstash output (Security Onion)](#step3)
5. [Test & enable Filebeat](#step4)
6. [Open SO firewall hostgroup (UI)](#step6)
7. [Network-level validation](#step7)

## Overview

### Goal

* Ship Suricata eve.json and Zeek logs from Debian → Security Onion 2.4.
* Use Filebeat → Logstash on port 5044 (Manager at 192.168.88.198).

### Prereqs

* Debian 13 with Suricata & Zeek writing to default paths.
* Security Onion 2.4 (standalone or manager) accessible on your LAN.

## 1) Install Filebeat on Debian 13

Elastic packages aren’t in Debian 13 by default. Add Elastic’s APT repo, then install.

```
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic.gpg

echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt update
sudo apt install -y filebeat
```

## 2) Configure inputs (Suricata & Zeek)

Copy

```
# /etc/filebeat/filebeat.yml (inputs section)
filebeat.inputs:
- type: log
  paths:
    - /var/log/suricata/eve.json
  fields:
    type: suricata
  fields_under_root: true

- type: log
  paths:
    - /opt/zeek/logs/current/*.log
  fields:
    type: zeek
  fields_under_root: true
```

## 3) Configure Logstash output (Security Onion)

Only one output may be active. Disable Elasticsearch output, enable Logstash:

Copy

```
# /etc/filebeat/filebeat.yml (output section)
# ---------------------------- Elasticsearch Output ----------------------------
#output.elasticsearch:
#  hosts: ["localhost:9200"]

# ------------------------------ Logstash Output -------------------------------
output.logstash:
  hosts: ["192.168.88.198:5044"]
```

## 4) Test & enable Filebeat

```
sudo filebeat test output
sudo systemctl enable --now filebeat
```

Expected: DNS resolves and TCP handshake succeeds once SO firewall allows your sender.

## 6) Open SO firewall hostgroup (UI)

1. SOC → Administration → Configuration → Firewall.
2. Open **Allow Elastic Agent endpoints to send logs**.
3. Add your sender(s): 192.168.88.0/24 (or a single IP like 192.168.88.97).
4. Save (✔). On standalone, changes apply automatically; UI may say “within ~15 minutes”.

## 7) Network-level validation

### From the sender (Debian)

```
nc -vz 192.168.88.198 5044
sudo filebeat test output
sudo journalctl -u filebeat -e --no-pager
```

### On Security Onion

```
sudo ss -lntp | grep 5044    # Logstash listening
sudo tcpdump -ni any port 5044
```

If you see SYN → SYN/ACK, the firewall path is open and Filebeat should ship events.

## Done

* Debian ships *Suricata* & *Zeek* via Filebeat to SO Logstash (5044).
* Firewall allows your sender via the *Elastic Agent endpoints* hostgroup.
* Check dashboards in SOC/Kibana for suricata.\* and zeek.\* fields.

## 8) Add SSH logging in Zeek

1. Check current Zeek logs:

   ```
   sudo ls -lh /opt/zeek/logs/current/
   ```
2. Enable SSH analyzers:

   ```
   sudo nano /opt/zeek/share/zeek/site/local.zeek
   ```

   ```
   @load base/protocols/ssh
   @load policy/protocols/ssh/detect-bruteforcing
   ```
3. Deploy Zeek to apply changes:

   ```
   sudo /opt/zeek/bin/zeekctl deploy
   ```
4. Verify the SSH service status (ensure there are no host-level errors):

   ```
   sudo systemctl status ssh
   ```
5. Generate SSH activity and confirm logs appear:

   ```
   sudo ls -lh /opt/zeek/logs/current/
   ```

![logo](img/logos/logo.png)

Learn.

Copy.

Impress.

* Tutorials
* [4rji.com](https://4rji.com)

4rjiDocs, all rights reserved. 2025 ©
