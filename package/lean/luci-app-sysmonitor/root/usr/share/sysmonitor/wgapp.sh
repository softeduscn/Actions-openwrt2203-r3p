#!/bin/sh

VPNserver="162.159.192.5"
NAME=sysmonitor
LOG_FILE=/var/log/$NAME.log
APP_PATH=/usr/share/$NAME


echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $1" >>$LOG_FILE
}

uci_get_by_type() {
	local ret=$(uci get $NAME.@$1[0].$2 2>/dev/null)
	echo ${ret:=$3}
}

uci_get_by_name() {
	local ret=$(uci get $NAME.$1.$2 2>/dev/null)
	echo ${ret:=$3}
}


wgvpn() {
	echolog "启用 Wireguard VPN ..."
	echo "" > /var/log/wgvpn.port
	if [ $run_mode == "gfw" ]; then
		mode="GFW"			
	else
		mode="CHN"			
	fi
	del_wg_rules $mode
	cat /etc/iproute2/rt_tables | grep $mode > /dev/null && sed -i '/^$/d;/$mode/d' /etc/iproute2/rt_tables
	add_wg_rules $mode
	echolog "Wireguard VPN ($mode) 完成配置!"
	return 0
}

del_wg_rules(){
	if [ ! $1 ];then
		if [ $run_mode == "gfw" ]; then
			mode="GFW"			
		else
			mode="CHN"			
		fi
	else
		mode=$1
		[ ! "$mode" == "CHN" -a ! "$mode" == "GFW" ] && return 3
	fi
	if [ "$(iptables -t mangle -L |grep wg$mode |wc -l)" -gt 0 ];then
		#echolog "清除Wireguard VPN ($mode)相关规则。"
		wg_name=$(cat /etc/iproute2/rt_tables | grep $mode | awk '{print $2s}' |cut -c4-7)
		iptables -t mangle -D OUTPUT -j wg$mode
		iptables -t mangle -D PREROUTING -j wg$mode
		iptables -t mangle -F wg$mode
		iptables -t mangle -X wg$mode
		for i in $wg_name; do
			del_wg_rule $i $mode 
		done	
	fi
	sed -i '/^$/d;/$mode/d' /etc/iproute2/rt_tables
}

add_wg_rules(){
	if [ ! $1 ];then
		if [ $run_mode == "gfw" ]; then
			mode="GFW"			
		else
			mode="CHN"			
		fi
	else
		mode=$1
		[ ! "$mode" == "CHN" -a ! "$mode" == "GFW" ] && return 3
	fi	
	wg_name=$(ifconfig |grep wg[0-9] |cut -c1-3)
	for i in $wg_name; do
		add_wg_rule $i $mode
	done
	return 0
}

del_wg_rule(){
	i=$1
	[ "$(echo $i |cut -c1-2)" != "wg" ] && return 3
	if [ ! $2 ];then
		if [ $run_mode == "gfw" ]; then
			mode="GFW"			
		else
			mode="CHN"			
		fi
	else
		mode=$2
		[ ! $mode == "CHN" -a ! $mode == "GFW" ] && return 3
	fi
	echolog "删除Wireguard VPN ($mode$i)规则。"
	iptables -D FORWARD -o $i -j ACCEPT
	iptables -t nat -D POSTROUTING -o $i -j MASQUERADE
	ip rule del fwmark 0xffff table $mode$i
	ip route del default dev $i table $mode$i
	sed -i -e 's/^[ \t]*//g'  -e '/^$/d' /var/log/wgvpn.port
	[ ! "$(cat /var/log/wgvpn.port |grep $i)" ] && echo $i >> /var/log/wgvpn.port
	sed -i /$mode$i/d /etc/iproute2/rt_tables
}

add_wg_rule(){
	i=$1
	[ "$(echo $i |cut -c1-2)" != "wg" ] && return 3
	if [ ! $2 ];then
		if [ $run_mode == "gfw" ]; then
			mode="GFW"			
		else
			mode="CHN"			
		fi
	else
		mode=$2
		[ ! "$mode" == "CHN" -a ! "$mode" == "GFW" ] && return 3
	fi	
	[ "$(iptables -t mangle -L wg$mode |grep 'match-set' | wc -l)" == 0 ] && $mode"_rules"
	k=$(echo $i |cut -c3)
	[ "$(cat /etc/iproute2/rt_tables |grep $mode$i |wc -l)" != 0 ] && return 3
	if [ "$mode" == "CHN" ]; then
		[ "$(cat /etc/iproute2/rt_tables |grep 20$k |wc -l)" != 0 ] && return 3
		echo "20$k $mode$i" >> /etc/iproute2/rt_tables
	else
		[ "$(cat /etc/iproute2/rt_tables |grep 21$k |wc -l)" != 0 ] && return 3
		echo "21$k $mode$i" >> /etc/iproute2/rt_tables
	fi
	echolog "创建Wireguard VPN ($mode$i)规则。"
	iptables -I FORWARD -o $i -j ACCEPT
	iptables -t nat -I POSTROUTING -o $i -j MASQUERADE
	ip rule add fwmark 0xffff table $mode$i
	ip route add default dev $i table $mode$i
	sed -i /$i/d /var/log/wgvpn.port
	return 0
}

GFW_rules(){
	mode="GFW"
	echolog "创建Wireguard VPN ($mode)相关规则。"
	iptables -t mangle -N wg$mode 2>/dev/null
	iptables -t mangle -F wg$mode
	iptables -t mangle -A wg$mode -m set --match-set gfwlist dst -j MARK --set-mark 0xffff
	iptables -t mangle -A wg$mode -m set --match-set blacklist dst -j MARK --set-mark 0xffff
	iptables -t mangle -C OUTPUT -j wg$mode 2>/dev/null|| iptables -t mangle -A OUTPUT -j wg$mode
	iptables -t mangle -C PREROUTING -j wg$mode 2>/dev/null|| iptables -t mangle -A PREROUTING -j wg$mode
}

CHN_rules(){
	mode="CHN"
	echolog "创建Wireguard VPN ($mode)相关规则。"
	iptables -t mangle -N wg$mode 2>/dev/null
	# 本地ip不走代理，非常重要，不然路由器都进不去
	iptables -t mangle -F wg$mode
	iptables -t mangle -A wg$mode -d 0.0.0.0/8 -j RETURN
	iptables -t mangle -A wg$mode -d 10.0.0.0/8 -j RETURN
	iptables -t mangle -A wg$mode -d 127.0.0.0/8 -j RETURN
	iptables -t mangle -A wg$mode -d 169.254.0.0/16 -j RETURN
	iptables -t mangle -A wg$mode -d 172.16.0.0/12 -j RETURN
	iptables -t mangle -A wg$mode -d 192.168.0.0/16 -j RETURN
	iptables -t mangle -A wg$mode -d 224.0.0.0/4 -j RETURN
	iptables -t mangle -A wg$mode -d 240.0.0.0/4 -j RETURN
	# 服务器ip/域名不走代理，修改为你自己的服务器地址wireguard_host，非常重要，启动脚本这里也要改
	iptables -t mangle -A wg$mode -d $VPNserver -j RETURN
	iptables -t mangle -A wg$mode -m set ! --match-set china dst -j MARK --set-mark 0xffff
	iptables -t mangle -A wg$mode -m set --match-set blacklist dst -j MARK --set-mark 0xffff
	iptables -t mangle -C OUTPUT -j wg$mode  2>/dev/null || iptables -t mangle -A OUTPUT -j wg$mode
	iptables -t mangle -C PREROUTING -j wg$mode  2>/dev/null || iptables -t mangle -A PREROUTING -j wg$mode
}

test_wgvpn(){
	wgvpn
	test_wg > /dev/null 2>&1 &
	return 0
}

switch_mode(){
	if [ $run_mode == "gfw" ]; then
		mode="GFW"
		uci set $NAME.@global[0].mode='router'
	else
		mode="CHN"
		uci set $NAME.@global[0].mode='gfw'
	fi
	uci commit $NAME
	del_wg_rules $mode
	wgvpn
	test_wg >/dev/null 2>&1 &
}

test_ping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(ping -A -c 1 -W 1 $url | grep -o 'max = [0-9]*' | awk -F '= ' '{print$2}')
		[ "$status" == "" ] && status=0
		if [ "$status" != 0 ]; then
			break
		else
			status=$(ping -c 1 -W 1 $url | grep -o 'time=[0-9]*' | awk -F '=' '{print$2}')
			[ "$status" == "" ] && status=0
		fi
		[ "$status" != 0 ] && break
	done
	echo $status
}

test_tcping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(tcping -c 1 $url |grep -o 'max = [0-9]*' | awk -F '= ' '{print$2}')
		[ "$status" == "" ] && status=0
		[ "$status" != 0 ] && break
	done
	echo $status
}


test_wg(){
	wg_name=$(ifconfig |grep wg[0-9] |cut -c1-3)
	if [ "$(test_ping_url '192.168.1.1')" == 0 ]; then
		echolog "网络异常 ，请检查wan..."
		#ifdown wan >/dev/null 2>&1 &
	else		
		k=0
		for i in $wg_name ; do
			[ "$(echo $i |cut -c1-2)" != "wg" ] && continue
			status=$(test_ping_url "$VPNserver -I $i")
			if [ "$status" != 0 ]; then
				echolog "Wireguard VPN $i-(VPNserver):$status"
				cat /etc/iproute2/rt_tables | grep $i > /dev/null
				if [ ! $? -eq 0 ];then
					add_wg_rule $i &
				fi
			else
				echolog "$i重置!"
				k=$(($k+1))
				del_wg_rule $i &
				#ifdown $i
				ifup $i
			fi
		done
		status=$(test_tcping_url "www.baidu.com")
		echolog "Wireguard VPN wan-(baidu):$status"
		status=$(test_tcping_url "www.google.com")
		echolog "Wireguard VPN wan-(google):$status\n"	
	fi	
}

if [ $wgenable == "1" ];then
	case $1 in
		del_wg_rules)
			del_wg_rules $2
			;;
		del_wg_rule)
			[ ! "$(cat /etc/iproute2/rt_tables |grep $2)" ] && return 3
			del_wg_rule $2 $3
			;;
		add_wg_rules)
			add_wg_rules $2
			;;
		add_wg_rule)
			wg_name=$(ifconfig |grep wg[0-9] |cut -c1-3)
			[ ! "$(echo $wg_name |grep $2)" ] && return 3
			add_wg_rule $2 $3
			;;
		switch_mode)
			switch_mode
			;;
		test_ping_url)
			test_ping_url $2
			;;
		test_tcping_url)
			test_tcping_url $2
			;;
		test_wg)
			test_wg
			;;
	esac
fi
case $1 in
	wgvpn)
		if [ $wgenable == "1" ];then
			/usr/bin/ssr-rules -x
			wgvpn
			test_wg >/dev/null 2>&1 &
		else
			del_wg_rules "CHN"
			del_wg_rules "GFW"
		fi
	;;
esac
