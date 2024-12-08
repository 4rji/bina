#!/usr/bin/env bash
iptables -D INPUT -p tcp --dport 80 -j ACCEPT
