#!/bin/sh
set -e

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

[lac aaisp]
lns = $L2TP_SERVER
require authentication = no
pppoptfile = /etc/ppp/options.aaisp
autodial = yes
redial = yes
redial timeout = 15
max redials = 9999
EOF

cat > /etc/ppp/options.aaisp <<EOF
+ipv6
ipv6cp-use-ipaddr
name $L2TP_USERNAME
password $L2TP_PASSWORD
noauth
ifname $L2TP_IFNAME
EOF

cat > /etc/ppp/ip-up.d/9999ifup <<EOF
#!/bin/sh -e

$L2TP_IFUP_COMMAND

exit 0
EOF
chmod +x /etc/ppp/ip-up.d/9999ifup

cat > /etc/ppp/ip-down.d/9999ifdown <<EOF
#!/bin/sh -e

$L2TP_IFDOWN_COMMAND

exit 0
EOF
chmod +x /etc/ppp/ip-up.d/9999ifup

if [ "$1" = 'client' ]; then
    echo "Starting client"
    exec /usr/sbin/xl2tpd -D -c /etc/xl2tpd/xl2tpd.conf
fi

exec "$@"
