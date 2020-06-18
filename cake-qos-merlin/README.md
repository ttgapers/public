/usr/sbin/curl --retry 3 "https://5m.ca/cake/cake-qos.sh" -o "/jffs/scripts/cake-qos" && chmod 0755 /jffs/scripts/cake-qos
/jffs/scripts/cake-qos install ac86u
/jffs/scripts/cake-qos enable 30Mbit 5Mbit "docsis ack-filter"
