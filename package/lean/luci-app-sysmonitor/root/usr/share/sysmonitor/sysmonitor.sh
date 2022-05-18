#!/bin/sh

if [ "$(ps -w | grep -v grep | grep sysmonitor.sh | wc -l)" -gt 2 ]; then
	exit 1
fi

sleep_unit=1
NAME=sysmonitor
APP_PATH=/usr/share/$NAME

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

ping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(ping -c 1 -W 1 $url | grep -o 'time=[0-9]*.*' | awk -F '=' '{print$2}'|cut -d ' ' -f 1)
		[ "$status" == "" ] && status=0
		[ "$status" != 0 ] && break
	done
	echo $status
}


while [ "1" == "1" ]; do #死循环

	homeip=$(uci_get_by_name $NAME sysmonitor homeip 0)
	vpnip=$(uci_get_by_name $NAME sysmonitor vpnip 0)
	dnsadd=$(uci_get_by_name network wan dns 0)
	runssr=0
	[ -f "/etc/init.d/shadowsocksr" ] && runssr=$(ps -w |grep ssr- |grep -v grep |wc -l)
	if [ "$runssr" == 0 ];then
		[ -f "/etc/init.d/passwall" ] && runssr=$(ps -w |grep passwall |grep -v grep |wc -l)
	fi
	if [ "$runssr" -gt 0 ]; then
		vpnok=0
		if [ $dnsadd == $vpnip ]; then
			uci set network.wan.gateway=$homeip
			uci set network.wan.dns=$homeip
			uci commit network
			ifup wan
			ifup wan6
			ifup lan
		fi
	else
		status=$(ping_url $vpnip)
		if [ "$status" == 0 ]; then
			vpnok=0
			if [ $dnsadd == $vpnip ]; then
				uci set network.wan.gateway=$homeip
				uci set network.wan.dns=$homeip
				uci commit network
				ifup wan
				ifup wan6
				ifup lan
			fi
		else
			vpnok=1
			if [ $dnsadd == $homeip ]; then
				uci set network.wan.gateway=$vpnip
				uci set network.wan.dns=$vpnip
				uci commit network
				ifup wan
				ifup wan6
				ifup lan
			fi
		fi
	fi

	/usr/share/sysmonitor/sysapp.sh getip >/www/localip.html
	/usr/share/sysmonitor/sysapp.sh getip6 >/www/localip6.html
	[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0

	num=0
	while [ $num -le 30 ]; do
		sleep $sleep_unit
		[ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ] && exit 0
		let num=num+sleep_unit
		runssr=0
		[ -f "/etc/init.d/shadowsocksr" ] && runssr=$(ps -w |grep ssr- |grep -v grep |wc -l)
		if [ "$runssr" == 0 ]; then 
			[ -f "/etc/init.d/passwall" ] && runssr=$(ps -w |grep passwall |grep -v grep |wc -l)
		fi
		dnsadd=$(uci_get_by_name network wan dns 0)
		if [ "$runssr" == 0 ]; then
			if [ "$vpnok" == 1 ]; then
				[ $dnsadd == $homeip ] && num=50
			fi
		else
			[ $dnsadd == $vpnip ] && num=50
		fi
		if [ -f "/tmp/sysmonitor" ]; then
			rm /tmp/sysmonitor
			num=50
		fi
	done
done

