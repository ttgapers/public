#!/bin/sh

case $1 in
        start)
        logger "Starting Cake queue management"
		runner disable 2>/dev/null
		fc disable 2>/dev/null
		fc flush 2>/dev/null
		insmod /opt/lib/modules/sch_cake.ko 2>/dev/null

		#WAN-eth0
		/opt/sbin/tc qdisc replace dev eth0 root cake bandwidth 13mbit besteffort nat docsis ack-filter

		ip link add name ifb9eth0 type ifb
		/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
		/opt/sbin/tc qdisc add dev eth0 handle ffff: ingress
		/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
		/opt/sbin/tc qdisc add dev ifb9eth0 root cake bandwidth 135mbit besteffort nat wash ingress docsis ack-filter
		ifconfig ifb9eth0 up
		/opt/sbin/tc filter add dev eth0 parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb9eth0
        ;;
        stop)
	logger "Stopping Cake queue management"
		##off
		/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
		/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
		/opt/sbin/tc qdisc del dev eth0 root 2>/dev/null
		ip link del ifb9eth0

		rmmod sch_cake 2>/dev/null
		fc enable
		runner enable
		;;
	*)
        echo "Usage: $0 {start|stop}"
        ;;
esac