
#!/bin/bash
# Script for Freifunk Vechta using Egderouter Firmware 1.10
# Add some workarounds because IPv6 modify rules inserted in the ipv4 ruleset (Bug) and ipv6 tables doesnt exist in the config tree on this firmware version
#
# INSTALLATION
# 1. Copy this script to /config/scripts
# 2. Create a symlink to run this script on boot: ln -s /config/scripts/ffvec-routing.sh /config/scripts/post-config.d/ffvec-routing.sh
# 3. Modify the Config Section
#
# FIREWALL MARKINGS (ipv6-modify table not working with 1.10)
# ipv6-modify FFVEC_MODIFY_V6 {
#        rule 10 {
#            action modify
#            modify {
#                mark 10
#            }
#            source {
#                address x:x:x:x::/64
#            }
#        }
#    }
#
# CRONJOB (yeah it's really ugly, so if anyone has a better idea):
# task UPDATE_ROUTING_FFVEC {
#    crontab-spec "*/5 * * * *"
#    executable {
#        path /config/scripts/ffvec-routing.sh
#    }
# }

### CONFIG SECTION ###
WIREGUARD_INTERFACE="wg1" # Destination Wireguard Interface
ROUTING_TABLE="10" # Routing table containing the forwarding information
FIREWALL_MARK="0xa/0xff" # See iptables -t mangle -L -v for the translated mark (10 = 0xa/0xff)

### SCRIPT SECTION ###
# Checks wether a from rule exists
# $1: 4 or 6
# $2: Mark
# $3: Destination Table
# Return: 0 if exists and 1 if not exists
function from_rule_exist() {
    if ip -"${1}" rule show | grep -q "from all fwmark ${2} lookup ${3}"; then
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

if ! from_rule_exist "4" "${FIREWALL_MARK}" "${ROUTING_TABLE}"; then
    ip rule add from all fwmark "${FIREWALL_MARK}" table "${ROUTING_TABLE}"
fi

if ! from_rule_exist "6" "${FIREWALL_MARK}" "${ROUTING_TABLE}"; then
    ip -6 rule add from all fwmark "${FIREWALL_MARK}" table "${ROUTING_TABLE}"
fi
