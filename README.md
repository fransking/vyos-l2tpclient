# vyos-l2tpclient
An l2tp client container for VyOS

## Usage

Create if-up script in /config/scripts/pppaa-up.sh (tweak to your requirements - eth1 assumed to be LAN)

```bash
#!/bin/sh

# start from clean state
pppaa-down.sh

# mss clamping
iptables -t mangle -A PREROUTING -i pppaa -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1300
iptables -t mangle -A POSTROUTING -o pppaa -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1300

# add local IPv6 address
ip addr add dev pppaa `add your WAN IPv6 address here e.g. 2001:xxx:xxx:xxx::1/64`

# add table 11 policy route over PPPAA
ip route add default dev pppaa proto static metric 20 table 11
ip -6 route add default dev pppaa proto static metric 20 table 11

# any packets inbound to the router over pppaa must go back out over pppaa
iptables -A INPUT -t mangle -i pppaa -j CONNMARK --set-mark 1
iptables -A OUTPUT -t mangle -j CONNMARK --restore-mark --mask 1

ip6tables -A INPUT -t mangle -i pppaa -j CONNMARK --set-mark 1
ip6tables -A OUTPUT -t mangle -j CONNMARK --restore-mark --mask 1

# any ipv4 connections (e.g. upnp) initiated to the lan from pppaa must go back out over pppaa
iptables -A PREROUTING -t mangle -i pppaa -j CONNMARK --set-mark 1
iptables -A PREROUTING -t mangle -i eth1 -m mark --mark 0 -j CONNMARK --restore-mark

exit 0
```

```
chmod +x /config/scripts/pppaa-up.sh
```

Create if-down script in /config/scripts/pppaa-down.sh (tweak to your requirements - eth1 assumed to be LAN)

```bash
#!/bin/sh

# removal of mss clamping
iptables -t mangle -D PREROUTING -i pppaa -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1300
iptables -t mangle -D POSTROUTING -o pppaa -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1300

# removal of any packets inbound to the router over pppaa must go back out over pppaa
iptables -D INPUT -t mangle -i pppaa -j CONNMARK --set-mark 1
iptables -D OUTPUT -t mangle -j CONNMARK --restore-mark --mask 1

ip6tables -D INPUT -t mangle -i pppaa -j CONNMARK --set-mark 1
ip6tables -D OUTPUT -t mangle -j CONNMARK --restore-mark --mask 1

# removal of any ipv4 connections (e.g. upnp) initiated to the lan from pppaa must go back out over pppaa
iptables -D PREROUTING -t mangle -i pppaa -j CONNMARK --set-mark 1
iptables -D PREROUTING -t mangle -i eth1 -m mark --mark 0 -j CONNMARK --restore-mark

# removal of table 11 policy route over PPPAA
ip route del default dev pppaa proto static metric 20 table 11
ip -6 route del default dev pppaa proto static metric 20 table 11

exit 0
```

```
chmod +x /config/scripts/pppaa-down.sh
```


Setup the container as per the VyOS documentation https://docs.vyos.io/en/latest/configuration/container/index.html#container

```
set container name l2tpclient image fransking/vyos-l2tpclient:latest
set container name l2tpclient device ppp source /dev/ppp
set container name l2tpclient device ppp destination /dev/ppp
set container name l2tpclient volume modules source /lib/modules
set container name l2tpclient volume modules destination /lib/modules
set container name l2tpclient volume l2tpclient source /config/l2tpclient
set container name l2tpclient volume l2tpclient destination /config/l2tpclient
set container name l2tpclient volume pppaa-ifup source /config/scripts/pppaa-up.sh
set container name l2tpclient volume pppaa-ifup destination /sbin/pppaa-up.sh
set container name l2tpclient volume pppaa-ifdown source /config/scripts/pppaa-down.sh
set container name l2tpclient volume pppaa-ifdown destination /sbin/pppaa-down.sh

set container name l2tpclient capability net-admin
set container name l2tpclient allow-host-networks
set container name l2tpclient environment 'L2TP_SERVER' value 'a.b.c.d'
set container name l2tpclient environment 'L2TP_USERNAME' value 'your username'
set container name l2tpclient environment 'L2TP_PASSWORD' value 'your password'
set container name l2tpclient environment 'L2TP_IFNAME' value 'pppaa'
set container name l2tpclient environment 'L2TP_IFUP_COMMAND' value 'pppaa-up.sh'
set container name l2tpclient environment 'L2TP_IFDOWN_COMMAND' value 'pppaa-down.sh'


# anything marked with fwmark 1 goes out of pppaa
set policy local-route rule 110 fwmark 1
set policy local-route rule 110 set table 11

# anything marked with fwmark 1 goes out of pppaa
set policy local-route6 rule 110 fwmark 1
set policy local-route6 rule 110 set table 11

# IPv4 PPPAA
# NAT for PPPAA
set nat source rule 5020 description 'masquerade for PPPAA'
set nat source rule 5020 outbound-interface name pppaa
set nat source rule 5020 translation address 'masquerade'

# policy route example to specific outbound via pppaa regardless of source
set policy route PPPAA_ROUTE rule 200 description 'Traffic via PPPAA'
set policy route PPPAA_ROUTE rule 200 set table 11
set policy route PPPAA_ROUTE rule 200 protocol all
set policy route PPPAA_ROUTE rule 200 destination address 8.8.8.8

set policy route PPPAA_ROUTE interface eth1


# IPv6 PPPAA 
# assigned one of your routed IPv6 subnets to eth1 (LAN)
set interfaces ethernet eth1 ipv6 address eui64 2001:xxx:xxx:xxy::/64


set firewall group ipv6-network-group LANSv6 network 2001:xxx:xxx:xxy::/64

# policy route example to send traffic from LAN IPv6 network(s) over PPPAA
set policy route6 PPPAA_ROUTE rule 200 description 'Traffic via PPPAA'
set policy route6 PPPAA_ROUTE rule 200 destination group network-group '!LANSv6'
set policy route6 PPPAA_ROUTE rule 200 set table 11
set policy route6 PPPAA_ROUTE rule 200 protocol all
set policy route6 PPPAA_ROUTE rule 200 source address 2001:xxx:xxx:xxy::/64

set policy route6 PPPAA_ROUTE interface eth1
```
