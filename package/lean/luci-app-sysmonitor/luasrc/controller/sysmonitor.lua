-- Copyright (C) 2017
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.sysmonitor", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/sysmonitor") then
		return
	end
	entry({"admin", "sys"}, firstchild(), "SYS", 10).dependent = false
   	entry({"admin", "sys","sysmonitor"}, alias("admin", "sys","sysmonitor", "settings"),_("SYSMonitor"), 20).dependent = true
	entry({"admin", "sys", "sysmonitor","settings"}, cbi("sysmonitor/setup"), _("General Settings"), 30).dependent = true
	entry({"admin", "sys", "sysmonitor", "update"}, form("sysmonitor/filetransfer"),_("Update"), 40).leaf = true
	entry({"admin", "sys", "sysmonitor", "log"},cbi("sysmonitor/log"),_("Log"), 50).leaf = true

	entry({"admin", "sys", "sysmonitor", "gateway_status"}, call("action_gateway_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "vpn_status"}, call("action_vpn_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wg_status"}, call("action_wg_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "ipsec_status"}, call("action_ipsec_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "pptp_status"}, call("action_pptp_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "switch_vpn"}, call("switch_vpn")).leaf = true
	entry({"admin", "sys", "sysmonitor", "refresh"}, call("refresh")).leaf = true
	entry({"admin", "sys", "sysmonitor", "refreshwg"}, call("refreshwg")).leaf = true
	entry({"admin", "sys", "sysmonitor", "onoff_vpn"}, call("onoff_vpn")).leaf = true
	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "firmware"}, call("firmware")).leaf = true
end

function get_log()
	luci.http.write(luci.sys.exec("[ -f '/var/log/sysmonitor.log' ] && cat /var/log/sysmonitor.log"))
end

function get_users()
    luci.http.write(luci.sys.exec(
                        "[ -f '/var/log/ipsec_users' ] && cat /var/log/ipsec_users"))
end


function action_gateway_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		gateway_state = luci.sys.exec("uci get network.wan.gateway")
	})
end

function action_vpn_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		vpn_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh ssr")
	})
end

function action_wg_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		wg_state = luci.sys.exec("curl http://47.100.183.141/getwg.php")
	})
end

function action_ipsec_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ipsec_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh ipsec")
	})
end

function action_pptp_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		pptp_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh pptp")
	})
end

function switch_vpn()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh switch_vpn")	
end

function onoff_vpn()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh onoff_vpn")	
end

function refresh()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("touch /tmp/sysmonitor")	
end

function refreshwg()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("curl http://47.100.183.141/flashwg.php")	
end

function firmware()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "log"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh firmware")
end