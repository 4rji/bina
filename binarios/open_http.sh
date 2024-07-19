#!/bin/bash
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
