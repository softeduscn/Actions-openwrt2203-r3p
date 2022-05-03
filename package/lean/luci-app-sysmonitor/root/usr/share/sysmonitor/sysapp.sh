#!/bin/sh

NAME=sysmonitor
APP_PATH=/usr/share/$NAME

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_get_by_type() {
	local ret=$(uci get $1.@$2[0].$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

uci_set_by_type() {
	uci set $1.@$2[0].$3=$4 2>/dev/null
	uci commit $1
}

agh() {
file1="/etc/AdGuardHome.yaml"
if [ -f $file1 ]; then
	status='Stopped'
	[ $(ps -w|grep -v grep|grep AdGuardHome|wc -l) -gt 0 ] && status='Running'
	num1=$(sed -n '/upstream_dns:/=' $file1)
	let num1=num1+1
	tmp='sed -n '$num1'p '$file1
	adguardhome=$($tmp)
	echo $status$adguardhome
else
	echo ""
fi
}

ssr() {
	ssrstatus=''
	ssr=''
	ssrp=''
	[ -f "/etc/init.d/shadowsocksr" ] && ssr='Shadowsocksr '
	[ -f "/etc/init.d/passwall" ] && ssrp='Passwall '
	if [ ! "$ssr" == '' ]; then
		ssrstatus='Stopped'
		[ "$(ps -w |grep ssrplus |grep -v grep |wc -l)" -gt 0 ] && ssrstatus='Running'
	fi
	if [ ! "$ssrp" == '' ]; then
		ssrpstatus='Stopped'
		[ "$(ps -w |grep /etc/passwall |grep -v grep |wc -l)" -gt 0 ] && ssrpstatus='Running'
	fi
	if [ "$ssr" == '' -a "$ssrp" == '' ]; then
		echo "No VPN Server installed."
	else
		if [ "$ssrstatus" == 'Running' ]; then
			echo $ssr$ssrstatus
		elif [ "$ssrpstatus" == 'Running' ]; then
			echo $ssrp$ssrpstatus
		else
			echo "VPN "$ssrpstatus
		fi
	fi
}

ipsec_users() {
	if [ -f "/usr/sbin/ipsec" ]; then
		ipsec_addr=$(ipsec leases|grep online|cut -d',' -f 3|cut -d' ' -f 5,11|sed "s/'//g")
		/usr/sbin/ipsec status > /tmp/ipsec_users
		tmp=$(cat /tmp/ipsec_users|cut -d':' -f 2|sed '/INSTALLED/d')
		echo $tmp|sed 's/ESTABLISHED/\nONLINE/g' > /tmp/ipsec_users
		echo '' > /tmp/log/ipsec_users
		for x in $ipsec_addr; do
			if [ $(echo $x|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"|wc -l) -gt 0 ]; then
				tmp=$x', '$(cat /tmp/ipsec_users|grep $x)
			else
				echo $x, $tmp >> /tmp/log/ipsec_users
			fi
		done
		users=$(/usr/sbin/ipsec status|grep Associations|cut -d' ' -f3|sed 's/^.//g')
		[ "$users" == "" ] && users='None'
	else
		users='None'
	fi
	echo $users
}

pptp_users() {
	if [ -f "/usr/sbin/pppd" ]; then
		users=$(top -bn1|grep pppd|grep -v grep|wc -l)
#		let users=users-1
		[ "$users" == 0 ] && users='None'
	else
		users='None'
	fi
	echo $users
}

wg() {
	if [ $(uci_get_by_name $NAME sysmonitor wgenable 0) == 0 ]; then
		if [ $(ifconfig |grep wg[0-9] |cut -c3-3|wc -l) != 0 ]; then
			wg_name=$(ifconfig |grep wg[0-9] |cut -c1-3)
			for x in $wg_name; do
			    ifdown $x &
			done
		fi
	else
		if [ $(ifconfig |grep wg[0-9] |cut -c3-3|wc -l) != 3 ]; then
			wg=$(ifconfig |grep wg[0-9] |cut -c1-3)
			wg_name="wg1 wg2 wg3"
			for x in $wg_name; do
				[ $(echo $wg|grep $x|wc -l) == 0 ] && ifup $x
			done
		fi
	fi
	wg=$(ifconfig |grep wg[0-9] |cut -c1-3)
	echo $wg
}

ad_del() {
	file1="/etc/AdGuardHome.yaml"
	num1=$(sed -n '/upstream_dns:/=' $file1)
	num2=$(sed -n '/upstream_dns_file:/=' $file1)
	let num1=num1+1
	let num2=num2-1
	tmp='sed -i '$num1','$num2'd '$file1
	[ $num1 -le $num2 ] && $tmp
}

ad_switch() {
	[ ! -f "/etc/init.d/AdGuardHome" ] && return
	adguardhome="  - "$1
	file1="/etc/AdGuardHome.yaml"
	if [ -f $file1 ]; then
		ad_del "upstream_dns:" "upstream_dns_file:"
		sed -i '/upstream_dns:/asqmshcn' $file1
		sed -i "s|sqmshcn|$adguardhome|g" $file1
		[ $(uci_get_by_name AdGuardHome AdGuardHome enabled 0) == 1 ] && /etc/init.d/AdGuardHome force_reload >/dev/null
	fi
}

switch_vpn() {
	if [ $(uci get sysmonitor.sysmonitor.vpn) == 0 ];  then
		onoff_vpn
	else
		if [ "$(ps -w|grep passwall|grep -v grep|wc -l)" == 0 ]; then
			if [ -f "/etc/init.d/passwall" ]; then
				uci set passwall.@global[0].enabled=1
				uci commit passwall
				[ -f "/etc/init.d/shadowsocksr" ] && /etc/init.d/shadowsocksr stop
				/etc/init.d/passwall restart
			fi
			echo "Passwall"
		elif [ "$(ps -w|grep ssrplus|grep -v grep|wc -l)" == 0 ]; then
			[ -f "/etc/init.d/passwall" ] && /etc/init.d/passwall stop
			[ -f "/etc/init.d/shadowsocksr" ] && /etc/init.d/shadowsocksr restart
			echo "Shadowsocksr"
		fi
	fi
}

onoff_vpn() {
	ssr=$(ps -w |grep /etc/passwall |grep -v grep |wc -l)
	[ $ssr -lt 1 ] && ssr=$(ps -w |grep ssrplus |grep -v grep |wc -l)
	if [ $ssr -gt 0 ];  then
		# Stop Passwall
		if [ "$(ps -w |grep /etc/passwall |grep -v grep |wc -l)" -gt 0 ]; then
			uci set passwall.@global[0].enabled=0
			uci commit passwall
			/etc/init.d/passwall stop
		fi
		# Stop Shadowsocksr
		[ "$(ps -w |grep ssrplus |grep -v grep |wc -l)" -gt 0 ] && /etc/init.d/shadowsocksr stop
		uci set sysmonitor.sysmonitor.vpn=0
	else
		if [ -f "/etc/init.d/passwall" ]; then
			if [ "$(ps -w |grep /etc/passwall |grep -v grep |wc -l)" -lt 1 ]; then
			if [ $(uci get passwall.@global[0].tcp_node) != 'nil' ]; then
				uci set passwall.@global[0].enabled=1
				uci commit passwall
				/etc/init.d/passwall restart &
			fi
			fi			
		elif [ -f "/etc/init.d/shadowsocksr" ]; then
			if [ "$(ps -w |grep ssrplus |grep -v grep |wc -l)" -lt 1 ]; then
			if [ $(uci get passwall.@global[0].enabled) == 0 ]; then
				/etc/init.d/shadowsocksr restart &
			fi
			fi
		else
			uci set sysmonitor.sysmonitor.vpn=0
			touch /tmp/sysmonitor
		fi
		uci set sysmonitor.sysmonitor.vpn=1		
	fi
	uci commit sysmonitor
}

firmware () {
	[ ! -d "/tmp/upload" ] && mkdir /tmp/upload
	cd /tmp/upload
	firmware=$(uci get sysmonitor.sysmonitor.firmware)
	[ "$1" != '' ] && firmware=$1
	tmp=$(echo $firmware|cut -d'/' -f 9)
	 [ -f $tmp ] && rm $tmp
	echo "Download Firmware:"$tmp"..." > /var/log/sysmonitor.log
	wget -c $firmware -O $tmp
	echo "Download Firmware is OK.">> /var/log/sysmonitor.log
	echo "Please go to Update">> /var/log/sysmonitor.log
}

upgrade() {
	if [ $(uci get sysmonitor.sysmonitor.config)  == 1 ]; then
		echo 'sysupgrade -c '$1 >> /var/log/sysmonitor.log
		sysupgrade -c $1
	else
		echo 'sysupgrade -n '$1 >> /var/log/sysmonitor.log
		sysupgrade -n $1
	fi
}

vlan() {
cat /etc/config/network | grep vlan > null
if [ $? -ne 0 ];then
cat >> /etc/config/network <<EOF
config device
	option name 'eth0'

config device
	option name 'lan1'

config device
	option name 'lan2'

config device
	option name 'lan3'

config device
	option name 'wan'

config device
	option name 'wlan0'

config device
	option name 'wlan1'

config device
	option type 'bridge'
	option name 'vlan'
	list ports 'eth0'
	list ports 'lan1'
	list ports 'lan2'
	list ports 'lan3'
	list ports 'wan'

config bridge-vlan
	option device 'vlan'
	option vlan '1'
	list ports 'eth0'
	list ports 'lan2'
	list ports 'lan3'

config bridge-vlan
	option device 'vlan'
	option vlan '2'
	list ports 'lan1'
	list ports 'wan'

config device
	option name 'vlan.1'
	option type '8021q'
	option ifname 'vlan'
	option vid '1'

config device
	option name 'vlan.2'
	option type '8021q'
	option ifname 'vlan'
	option vid '2'
EOF

uci set network.lan.device='vlan.1'
uci set network.wan6.device='vlan.2'
uci set network.wan.device='vlan.2'
uci commit network
/etc/init.d/network reload 2>/dev/null
wifi up
fi
}

arg1=$1
shift
case $arg1 in

agh)
	agh
	;;
ssr)
	ssr
	;;
ipsec)
	ipsec_users
	;;
pptp)
	pptp_users
	;;
wg)
	wg
	;;
vlan)
	vlan
	;;
onoff_vpn)
	onoff_vpn
	;;
switch_vpn)
	switch_vpn
	;;
ad_switch)
	ad_switch $1
	;;
firmware)
	firmware $1
	;;
upgrade)
	upgrade $1
	;;
test)
	echo $1

	;;

esac
