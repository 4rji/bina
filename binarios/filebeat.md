[![logo](img/logos/logo.png)](index.html)

* [Home](index.html)* * [Scripts](scripts.html)
    * [Search](search.html)

# Filebeat and Elasticsearch Installation

## Suricata and Zeek Configuration

### Project Highlights

#### Log shipping project focused on Filebeat, Elasticsearch, Suricata, and Zeek to collect, index, and validate security telemetry from a Linux sensor.

* Installed Elasticsearch and Filebeat with the Elastic APT repository and custom helper
  scripts.
* Configured Suricata `eve.json` output and enabled Filebeat modules for Suricata and
  Zeek telemetry.
* Set Filebeat Elasticsearch output with credentials, CA fingerprinting, and service
  startup validation.
* Created API keys and verification commands to confirm indexed Filebeat, Suricata, and
  Zeek data.

**Install Zeek with the script:**
zeekinst

**Then install with the script:**
suricatainst

**sudo nano /etc/suricata/suricata.yaml
There modify the network card as shown by the script. Comment these lines:**

```
# Cross platform libpcap capture support
pcap:
  - interface: ens192
    # On Linux, pcap will try to use mmap'ed capture and will use "buffer-size"
    # as total memory used by the ring. So set this to something bigger
    #promisc: no
    # set snaplen, if not set it defaults to MTU if MTU can be known
    # via ioctl call and to full capture if not.
    #snaplen: 1518
  # Put default values here
  - interface: default
    #checksum-checks: auto
```

**Download this script to save time on the installation steps—just configure the files as needed:**

[Download installation script: elast-fileb-inst](https://raw.githubusercontent.com/4rji/bina/refs/heads/main/binarios/elast-fileb-inst)

**If you ran the** `elast-fileb-inst` **script, skip steps: 1, 2, 4, 5.**

```
elast-fileb-inst
```

Elasticsearch & Filebeat Installation — Steps

# Elasticsearch & Filebeat Installation — Steps

## 1 Import Elasticsearch GPG key (wget)

```
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
```

## 2 Install apt transport and Elasticsearch

```
sudo apt-get install apt-transport-https
sudo apt-get update && sudo apt-get install elasticsearch
```

## 3 Filebeat / Suricata

Verify it is like this. The main file is `/etc/suricata/suricata.yaml`

```
sudo nano /etc/suricata/suricata.yaml
outputs:
  # a line based alerts log similar to Snort's fast.log
  - fast:
      enabled: yes
      filename: fast.log
      append: yes
      #filetype: regular # 'regular', 'unix_stream' or 'unix_dgram'

  # Extensible Event Format (nicknamed EVE) event log in JSON format
  - eve-log:
      enabled: yes
      filetype: regular #regular|syslog|unix_dgram|unix_stream|redis
      filename: eve.json
```

## 4 Import the key and repository

```
# Importa la llave y repositorio
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
 | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
```

## 5 Install

```
# Instala
sudo apt update
sudo apt install elasticsearch -y
```

## 6 Enable Filebeat Suricata module and edit

```
sudo filebeat modules enable suricata zeek

sudo nano /etc/filebeat/modules.d/suricata.yml

- module: suricata
  # All logs
  eve:
    enabled: true
    var.paths: ["/var/log/suricata/eve.json"]

Now run the zeekmodules script to add the zeek modules
zeekmodules
```

## 7 Set password

```
#set password
sudo systemctl enable --now elasticsearch
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -i
```

## 8 Edit Filebeat output to Elasticsearch

```
sudo nano /etc/filebeat/filebeat.yml

#ATENTION: tener cuidado con espacios y lineas aqui:
# ---------------------------- Elasticsearch Output ----------------------------
output.elasticsearch:
  hosts: ["https://localhost:9200"]
  username: "elastic"
  password: "rancid12"
  ssl:
    enabled: true
    ca_trusted_fingerprint: "b9a10bbe64ee9826abeda6546fc988c8bf798b41957c33d05db736716513dc9c"
```

## 9 Enable on boot and start

```
sudo systemctl enable --now zeek suricata filebeat elasticsearch
sudo systemctl restart zeek suricata filebeat elasticsearch
systemctl is-active zeek suricata filebeat elasticsearch | grep -v inactive

sudo filebeat setup -e
```

## 10 Create API Keys and Variables

```
# ===========================================
# 1. CREATE BASIC API KEY (Full Access)
# ===========================================
curl --cacert /etc/elasticsearch/certs/http_ca.crt -u elastic:rancid12 \
  -H 'Content-Type: application/json' \
  -X POST https://localhost:9200/_security/api_key \
  -d '{"name":"mi-aplicacion","expiration":"90d"}'# ===========================================
# 2. CREATE READ-ONLY API KEY (Restricted)
# ===========================================
curl --cacert /etc/ssl/certs/es-http-ca.crt -u elastic:rancid12 \
  -H 'Content-Type: application/json' \
  -X POST https://localhost:9200/_security/api_key \
  -d '{
    "name":"mi-app-ro-cat",
    "expiration":"90d",
    "role_descriptors":{
      "ro_cat":{
        "cluster":["monitor"],
        "indices":[
          { "names":["*"], "privileges":["read","view_index_metadata","monitor"] }
        ]
      }
    }
  }'# ===========================================
# 3. SET ENVIRONMENT VARIABLES
# ===========================================
USER=elastic
PASS='rancid12'

# Reload shell
```

The first command creates a basic API key for your application. The second command creates a read-only API key with restricted permissions - use this for applications that only need to read data from Elasticsearch, not write or modify anything. This follows the principle of least privilege for better security.

## 11 Test

If everything went well you can run the script called "suricatatest" and you should see something like in the image

![Filebeat test result](img/filebeat/test.webp)

Now test Zeek DNS with the script `zeektest`. You should see something like this:

![Zeek DNS test result](img/filebeat/zeektest.webp)

## 12 Other verification commands

For other tests you can run the following:

```
curl -sS -k -u "$USER:$PASS" 'https://localhost:9200/_cat/indices?v'
```

```
sudo sh -c "curl -sS --cacert /etc/elasticsearch/certs/http_ca.crt -u '$USER:$PASS' 'https://localhost:9200/filebeat-*/_search' -H 'Content-Type: application/json' -d '{\"size\":1}'" | jq .
```

```
sudo curl -sS -k -u "$USER:$PASS" \
'https://localhost:9200/filebeat-*/_search' \
-H 'Content-Type: application/json' -d '{
  "size":0,
  "aggs":{"mods":{"terms":{"field":"event.module","size":20}}}
}'
```

![logo](img/logos/logo.png)

Learn.

Copy.

Impress.

* Tutorials
* [4rji.com](https://4rji.com)

4rjiDocs, all rights reserved. 2025 ©
