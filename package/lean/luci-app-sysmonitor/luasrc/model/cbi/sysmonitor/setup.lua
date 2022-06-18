
local m, s
local global = 'sysmonitor'
local uci = luci.model.uci.cursor()
--ip = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip")
m = Map("sysmonitor",translate("System Monitor"))

m:append(Template("sysmonitor/status"))

s = m:section(TypedSection, "sysmonitor", translate("System Settings"))
s.anonymous = true
--s.description ='<style>.button1 {-webkit-transition-duration: 0.4s;transition-duration: 0.4s;padding: 4px 16px;text-align: center;background-color: white;color: black;border: 2px solid #4CAF50;border-radius:5px;}.button1:hover {background-color: #4CAF50;color: white;}.button1 {font-size: 13px;}</style><button class="button1"><a href="http://'..ip..':7681" target="_blank" title="Open a ttyd terminal">' .. translate("OpenTerminal") .. '</a></button>'

o=s:option(Flag,"enable", translate("Enable"))
o.rmempty=false

o=s:option(Flag,"bbr", translate("BBR Enable"))
o.rmempty=false

if nixio.fs.access("/etc/init.d/passwall") or nixio.fs.access("/etc/init.d/shadowsocksr") then
o=s:option(Flag,"vpn", translate("VPN Enable"))
o.rmempty=false
end

if nixio.fs.access("/etc/init.d/ipsec") then
o=s:option(Flag,"ipsec", translate("IPSEC Enable"))
o.rmempty=false
end

if nixio.fs.access("/etc/init.d/luci-app-pptp-server") then
o=s:option(Flag,"pptp", translate("PPTP Enable"))
o.rmempty=false
end

if nixio.fs.access("/etc/init.d/smartdns") then
o=s:option(Flag,"smartdnsAD", translate("SmartDNS-AD Enable"))
o.rmempty=false
end

o = s:option(Value, "homeip", translate("Home IP Address"))
--o.description = translate("IP for Home(192.168.1.1)")
o.datatype = "or(host)"
o.rmempty = false

o = s:option(Value, "vpnip", translate("VPN IP Address"))
--o.description = translate("IP for VPN Server(192.168.1.110)")
o.datatype = "or(host)"
o.rmempty = false

o=s:option(Value,"minidlna", translate("Minidlna directory"))
o.rmempty=false

o = s:option(Value, translate("firmware"), translate("Firmware Address"))
--o.description = translate("Firmeware download Address)")
o.default = "https://github.com/softeduscn/Actions-openwrt1907-r3p/releases/download/MI-R3P/openwrt-ramips-mt7621-xiaomi_mir3p-squashfs-sysupgrade.bin"
o.rmempty = false

return m
