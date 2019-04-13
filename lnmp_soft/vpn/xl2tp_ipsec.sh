#!/bin/bash

xl2tpd_conf="/etc/xl2tpd/xl2tpd.conf"
ipsec_conf="/etc/ipsec.conf"

#配置IPsec
read -p "请输入服务器外网网卡IP:" serverIP
cat > /etc/ipsec.d/myipsec.conf <<EOF
conn IDC-PSK-NAT
    rightsubnet=vhost:%priv
    also=IDC-PSK-noNAT

conn IDC-PSK-noNAT
    authby=secret
        ike=3des-sha1;modp1024
        phase2alg=aes256-sha1;modp2048
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=3h
    type=transport
    left=$serverIP
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
EOF

cat > /etc/ipsec.d/mypass.secrets <<EOF
$serverIP  %any:  PSK   "randpass"
EOF

#修改内核参数
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p &> /dev/null

#启动IPsec服务
systemctl restart ipsec
systemctl enable ipsec  &>/dev/null


#配置xl2tpd

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
[lns default]
ip range = 192.168.1.128-192.168.1.254
local ip = $serverIP
require chap = yes
refuse pap = yes
require authentication = yes
name = VPNserver
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF


cat > /etc/ppp/options.xl2tpd <<EOF
#refuse-pap
#refuse-chap
#refuse-mschap
require-mschap-v2
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
noccp
auth
idle 7200
mtu 1410
mru 1410
nodefaultroute
#debug
proxyarp
connect-delay 5000
#nobsdcomp
#multilink
passive
lcp-echo-interval 60
lcp-echo-failure 3
novj
novjccomp
nologfd
EOF

read -p "请输入VPN账户名称:" user
read -p "请输入VPN账户密码:" pass

cat >> /etc/ppp/chap-secrets <<EOF
$user  *  $pass  *
EOF

systemctl restart xl2tpd
systemctl enable xl2tpd  &>/dev/null
