
local m, s
local global = 'sysmonitor'
local uci = luci.model.uci.cursor()

m = Map("sysmonitor",translate("System Monitor"))

m:append(Template("sysmonitor/status"))

s = m:section(TypedSection, "sysmonitor", translate("System Settings"))
s.anonymous = true

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

o=s:option(Flag,"config", translate("Keep config"))
o.rmempty=false

o = s:option(Value, translate("firmware"), translate("Firmware Address"))
--o.description = translate("Firmeware download Address)")
o.default = "https://github.com/softeduscn/Actions-openwrt1907-r3p/releases/download/MI-R3P/openwrt-ramips-mt7621-xiaomi_mir3p-squashfs-sysupgrade.bin"
o.rmempty = false

return m
