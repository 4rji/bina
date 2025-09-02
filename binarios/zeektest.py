#!/usr/bin/env python3

#pip install requests tabulate



import requests
import json
from tabulate import tabulate

ES_URL = "https://localhost:9200"
ES_USER = "elastic"
ES_PASS = "rancid12"
INDEX   = "filebeat-*"
VERIFY  = False   # pon la ruta del http_ca.crt si quieres validar

def get_dns_events(size=10):
    query = {
        "size": size,
        "sort": [{"@timestamp": "desc"}],
        "query": {"term": {"event.dataset": "zeek.dns"}},
        "_source": [
            "@timestamp",
            "zeek.dns.query",
            "zeek.dns.qtype",
            "zeek.dns.rcode",
            "source.ip",
            "destination.ip"
        ]
    }

    url = f"{ES_URL}/{INDEX}/_search"
    resp = requests.post(url, auth=(ES_USER, ES_PASS),
                         headers={"Content-Type": "application/json"},
                         data=json.dumps(query), verify=VERIFY)

    if resp.status_code != 200:
        print("Error:", resp.status_code, resp.text)
        return []

    hits = resp.json().get("hits", {}).get("hits", [])
    return [h["_source"] for h in hits]

def main():
    events = get_dns_events(10)
    if not events:
        print("No hay resultados")
        return

    table = []
    for e in events:
        table.append([
            e.get("@timestamp", ""),
            e.get("source", {}).get("ip", ""),
            e.get("destination", {}).get("ip", ""),
            e.get("zeek", {}).get("dns", {}).get("query", ""),
            e.get("zeek", {}).get("dns", {}).get("qtype", ""),
            e.get("zeek", {}).get("dns", {}).get("rcode", ""),
        ])

    headers = ["timestamp", "src_ip", "dst_ip", "query", "qtype", "rcode"]
    print(tabulate(table, headers=headers, tablefmt="github"))

if __name__ == "__main__":
    main()
