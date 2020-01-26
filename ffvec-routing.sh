#!/bin/bash
# Script for Freifunk Vechta using Egderouter Firmware 1.10
# Add some workarounds because IPv6 modify rules inserted in the ipv4 ruleset (Bug) and ipv6 tables doesnt exist in the config tree on this firmware version
# So we're doing this manually using this script
#
# INSTALLATION
# 1. Copy this script to /config/scripts
# 2. Create a symlink to run this script on boot: ln -s /config/scripts/ffvec-routing.sh /config/scripts/post-config.d/ffvec-routing.sh
# 3. Modify the Config Section
#
# CRONJOB
# Is only needed when you recreate your wireguard interface using the config tree
# Prevents some downtime in case the route will be deleten
# task UPDATE_ROUTING_FFVEC {
#    crontab-spec "*/5 * * * *"
#    executable {
#        path /config/scripts/ffvec-routing.sh
#    }
# }

### CONFIG SECTION ###
WIREGUARD_INTERFACE="wg1" # Destination Wireguard Interface
ROUTING_TABLE="10" # Routing table containing the forwarding information
INCOMING_INTERFACE="eth1.251" # Interface from which the traffic should be forwarded through the tunnel

### SCRIPT SECTION ###
# Checks wether a from rule exists
# $1: 4 or 6
# $2: Incoming Interface
# $3: Destination Table
# Return: 0 if exists and 1 if not exists
function from_rule_exist() {
    if ip -"${1}" rule show | grep -q "from all iif ${2} lookup ${3}"; then
        return 0
    else
        return 1
    fi
}

# Add policy based routes if not exists and ignore if they're already exists
ip route add default dev "${WIREGUARD_INTERFACE}" table "${ROUTING_TABLE}" || true
ip route add blackhole 0.0.0.0/0 metric 255 table "${ROUTING_TABLE}" || true

ip -6 route add default dev "${WIREGUARD_INTERFACE}" metric 254 table "${ROUTING_TABLE}" || true
ip -6 route add blackhole ::/0 metric 255 table "${ROUTING_TABLE}" || true

if ! from_rule_exist "4" "${INCOMING_INTERFACE}" "${ROUTING_TABLE}"; then
    ip rule add from all dev "${INCOMING_INTERFACE}" table "${ROUTING_TABLE}"
fi

if ! from_rule_exist "6" "${INCOMING_INTERFACE}" "${ROUTING_TABLE}"; then
    ip -6 rule add from all dev "${INCOMING_INTERFACE}" table "${ROUTING_TABLE}"
fi

