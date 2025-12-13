# -----------------------
# Palo Alto baseline (new topo)
# Inside:  172.20.242.254/24
# Outside: 172.16.101.254/24
# Mgmt:    172.20.242.150
#
# Servers:
#   Splunk LAN   172.20.242.20   PUBLIC 172.25.39.9
#   Webmail LAN  172.20.242.101  PUBLIC 172.25.39.39
#   Ecom   LAN   172.20.242.104  PUBLIC 172.25.39.11
# -----------------------

set deviceconfig system permitted-ip 172.20.242.0/24
set deviceconfig system login-banner AuthorizedAccessOnly

# restrict management access
set network profiles interface-management-profile Default ping no https yes ssh yes telnet no http no snmp no response-pages no
set network profiles interface-management-profile Default permitted-ip 172.20.242.0/24
set network interface ethernet ethernet1/1 layer3 interface-management-profile Default
set network interface ethernet ethernet1/2 layer3 interface-management-profile Default
set network interface ethernet ethernet1/3 layer3 interface-management-profile Default
set network interface ethernet ethernet1/4 layer3 interface-management-profile Default

# profile group
set profile-group ProFilter file-blocking "strict file blocking" spyware default url-filtering default virus default vulnerability default wildfire-analysis default

###############################################################################
# Zone protection profile
###############################################################################
set network profiles zone-protection-profile ZoneRulz discard-tcp-synack-with-data yes
set network profiles zone-protection-profile ZoneRulz discard-timestamp yes
set network profiles zone-protection-profile ZoneRulz discard-unknown-option yes
set network profiles zone-protection-profile ZoneRulz remove-tcp-timestamp yes
set network profiles zone-protection-profile ZoneRulz strict-ip-check yes
set network profiles zone-protection-profile ZoneRulz strip-mptcp-option yes
set network profiles zone-protection-profile ZoneRulz strip-tcp-fast-open-and-data yes
set network profiles zone-protection-profile ZoneRulz suppress-icmp-needfrag yes
set network profiles zone-protection-profile ZoneRulz suppress-icmp-timeexceeded yes
set network profiles zone-protection-profile ZoneRulz tcp-reject-non-syn yes

set network profiles zone-protection-profile ZoneRulz flood tcp-syn enable yes red activate-rate 10000 alarm-rate 10000 maximal-rate 10000
set network profiles zone-protection-profile ZoneRulz flood udp enable yes red activate-rate 10000 alarm-rate 10000 maximal-rate 10000
set network profiles zone-protection-profile ZoneRulz flood icmp enable yes red activate-rate 10000 alarm-rate 10000 maximal-rate 10000
set network profiles zone-protection-profile ZoneRulz flood other-ip enable yes red activate-rate 10000 alarm-rate 10000 maximal-rate 10000
set network profiles zone-protection-profile ZoneRulz flood icmpv6 enable yes red alarm-rate 1000 activate-rate 2000 maximal-rate 3000

# attach zone-protection-profile to zones
set zone External network zone-protection-profile ZoneRulz
set zone Internal network zone-protection-profile ZoneRulz
set zone Public network zone-protection-profile ZoneRulz
set zone User network zone-protection-profile ZoneRulz

###############################################################################
# Security rules
###############################################################################

# default scoring allow (limited apps)
set rulebase security rules AllowScoring profile-setting group ProFilter
set rulebase security rules AllowScoring from any to any source any destination any application [ dns ssl web-browsing ] action allow service application-default log-start yes log-end yes

# Webmail inbound (PUBLIC IP)
set rulebase security rules WebMail-Inbound profile-setting group ProFilter
set rulebase security rules WebMail-Inbound from [ External Public ] to [ Public External ] source any destination 172.25.39.39 action allow service application-default
set rulebase security rules WebMail-Inbound application [ dns web-browsing ssl smtp pop3 imap ] log-start yes log-end yes

# Webmail outbound (LAN IP)
set rulebase security rules WebMail-Out profile-setting group ProFilter
set rulebase security rules WebMail-Out from Public to External source 172.20.242.101 destination any action allow service application-default
set rulebase security rules WebMail-Out application [ dns web-browsing ssl smtp pop3 imap ] log-start yes log-end yes

# NTP out (generic)
set rulebase security rules NTP-Out profile-setting group ProFilter
set rulebase security rules NTP-Out from [ Internal User Public ] to External source any destination any application ntp action allow service application-default log-start yes log-end yes

# Splunk receiving (1514 + 9998) -> Splunk LAN
set service Splunk-1514 protocol udp port 1514
set service Splunk-1514 protocol tcp port 1514
set service Splunk-9998 protocol tcp port 9998

set rulebase security rules Splunk-Internal-Logging profile-setting group ProFilter
set rulebase security rules Splunk-Internal-Logging from [ Internal User Public ] to Public source [ 172.20.242.101 172.20.242.104 172.20.242.150 ] destination 172.20.242.20 application any action allow
set rulebase security rules Splunk-Internal-Logging service Splunk-1514 log-start yes log-end yes

set rulebase security rules Splunk-User-9998 profile-setting group ProFilter
set rulebase security rules Splunk-User-9998 from User to Public source any destination 172.20.242.20 application splunk action allow
set rulebase security rules Splunk-User-9998 service Splunk-9998 log-start yes log-end yes

# Palo Alto updates (mgmt)
set rulebase security rules PaloOutUpdate from User to External source 172.20.242.150 destination any application [ pan-db-cloud paloalto-updates paloalto-wildfire-cloud ] service application-default action allow log-start yes log-end yes

# allow common package repos / downloads
set rulebase security rules Allow-File from [ Internal User Public ] to External source any destination any application [ github apt-get google-base yum ] service application-default action allow log-start yes log-end yes

# deny noisy/bad stuff (keep your list)
set rulebase security rules BlockBad from any to any source any destination any application [ telnet ms-rdp vnc ftp tftp snmp ms-ds-smb rpc ms-rdp http-proxy ssh ] action deny service application-default log-start yes log-end yes

# optional: allow icmp generally (if you want)
set rulebase security rules Allow-ICMP-Global from any to any source any destination any application ping action allow service application-default log-start yes log-end yes

# final deny
set rulebase security rules Deny-All from any to any source any destination any application any service any action deny log-start yes log-end yes

# content updates (optional)
request anti-virus upgrade install version latest
request wildfire upgrade install version latest
request content upgrade install version latest

commit