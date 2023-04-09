#!/bin/bash

urlencode() {
	local LANG=C
	local length="${#1}"
	i=0
	while :; do
		[ $length -gt $i ] && {
			local c="${1:$i:1}"
			case $c in
			[a-zA-Z0-9.~_-]) printf "$c" ;;
			*) printf '%%%02X' "'$c" ;;
			esac
		} || break
		let i++
	done
}

urldecode() {
	u="${1//+/ }"
	echo -e "${u//%/\\x}"
}

# 从tomlink.uk获取源文件
curl "https://sub.tomlink.win/api/v1/client/subscribe?token=mytoken" > /opt/clash4linux/clash-for-linux/dev/subscribe.origin.base64.conf

# base64解码源文件
base64 -d /opt/clash4linux/clash-for-linux/dev/subscribe.origin.base64.conf > /opt/clash4linux/clash-for-linux/dev/subscribe.decode.base64.conf


proxy_template="    - { name: '_name', type: _type, server: _server, port: _port, cipher: _cipher, password: _password, udp: true }"
proxy_group_template="  - { name: TomLink, type: select, proxies: [_namelist] }"
namelist=""

# 处理代理节点
cat /opt/clash4linux/clash-for-linux/dev/proxies.conf.tml > /opt/clash4linux/clash-for-linux/dev/proxies.conf
while read line
do
    proxy=$proxy_template
    info=($(echo $line|awk -F'@|#' '{print substr($1,6),$2,$3}'))
    for((i=0;i<3;i++))
    do
	if [[ $i -eq 0 ]];then
	    pwd=($(echo -n "${info[i]}="|base64 -di|awk -F':' '{print $1,$2}'))
            proxy=$(echo $proxy|sed  "s/_cipher/${pwd[0]}/g")
            proxy=$(echo $proxy|sed  "s/_password/${pwd[1]}/g")
	elif [[ $i -eq 1 ]];then
	    host=($(echo "${info[i]}"|awk -F':' '{print $1,$2}'))
	    proxy=$(echo $proxy|sed  "s/_server/${host[0]}/g")
            proxy=$(echo $proxy|sed  "s/_port/${host[1]}/g")
	else
	    name=$(echo $(urldecode ${info[i]}|sed 's/ /_/g')|tr -d '\n\r')
	    namelist="'"$name"'"","$namelist
	    type="ss"
	    proxy=$(echo $proxy|sed "s/_name/$name/g")
	    proxy=$(echo $proxy|sed "s/_type/${type}/g")
	fi
    done
    echo "    "$proxy >> /opt/clash4linux/clash-for-linux/dev/proxies.conf
done < /opt/clash4linux/clash-for-linux/dev/subscribe.decode.base64.conf 

# 处理代理分组
namelist=$(echo $namelist|sed 's/.$//')
proxy_group=$(echo $proxy_group_template|sed "s/_namelist/${namelist}/g")
cat /opt/clash4linux/clash-for-linux/dev/proxies-group.conf.tml > /opt/clash4linux/clash-for-linux/dev/proxies-group.conf
echo "    "$proxy_group >> /opt/clash4linux/clash-for-linux/dev/proxies-group.conf

# 合并所有配置-->一个配置文件：config.yaml
cat /opt/clash4linux/clash-for-linux/dev/config.yaml.conf > /opt/clash4linux/clash-for-linux/dev/config.yaml
cat /opt/clash4linux/clash-for-linux/dev/proxies.conf >> /opt/clash4linux/clash-for-linux/dev/config.yaml
cat /opt/clash4linux/clash-for-linux/dev/proxies-group.conf >> /opt/clash4linux/clash-for-linux/dev/config.yaml
cat /opt/clash4linux/clash-for-linux/dev/rules.conf >> /opt/clash4linux/clash-for-linux/dev/config.yaml 
