#!/bin/sh

# 检查网络是否畅通 telnet www.youtube.com 80
# 调用SSR ping全部
# 调用获取SSR节点 并解析出最快节点
# 设置节点 set global_server=78
# 重启 /usr/bin/shadowsocks.sh reserver &

#解析返回值 并设置新的可用节点
get_allssr(){
	port=0
	ping_ttl=99999;
	OLDPORT=`nvram get global_server`
	RESULT=`curl --location --request GET 'http://172.19.56.1/dbconf?p=ss'`
	#去头
	RESULT=`echo $RESULT | sed 's/var db_ss=(function() { var o={}; /''/g'`
	#去尾
	RESULT=`echo $RESULT | sed 's/ return o; })();/''/g'`
	RESULT=`echo $RESULT | sed 's/o\[\"ssconf_basic_json_/''/g'`
	RESULT=`echo $RESULT | sed 's/'\''/''/g'`
	#替换空格
	RESULT=`echo $RESULT | sed 's/ /''/g'`
	splits=$(echo $RESULT | tr ";" "\n")
	for splitdata in $splits
	do
		result=$(echo $splitdata | grep "ping")
	    	if [[ "$result" != "" ]]
			then
			ssr_point=`echo $splitdata | sed "s/\]={\"ping\":\"//g"`
			temp_str=`echo $ssr_point | cut -d\" -f 2-`
			# ping值
			ttls=`echo $temp_str | cut -d\" -f 1`
			if [ ${#ttls} -lt 4 ] &&  [ $ttls -lt $ping_ttl ] &&  [ $ttls != $OLDPORT ]
				then
				ping_ttl=$ttls
				port=`echo $ssr_point | cut -d\" -f 1`
			fi
		fi
	done
	echo "$(date "+%Y-%m-%d %H:%M:%S") 筛选完毕，节点编号： $port，其ping值：$ping_ttl ms" >> /etc/storage/logs/ssr_updateport.log
	if [ $ping_ttl != 99999 ] && [ $port != 0 ]
		then
		#设置新节点
		nvram set global_server=$port
		#触发重连按钮 使配置生效
		curl --location --request POST 'http://172.19.56.1/Shadowsocks_action.asp' \
		--header 'Accept:  application/json, text/javascript, */*; q=0.01' \
		--header 'Accept-Encoding:  gzip, deflate' \
		--header 'Accept-Language:  zh-CN,zh;q=0.9' \
		--header 'Authorization:  Basic YWRtaW46Q2xpbmcqMDAwMDA=' \
		--header 'Connection:  keep-alive' \
		--header 'Content-Length:  24' \
		--header 'Content-Type: application/x-www-form-urlencoded' \
		--header 'DNT:  1' \
		--header 'Host:  172.19.56.1' \
		--header 'Origin:  http://172.19.56.1' \
		--header 'Referer:  http://172.19.56.1/Shadowsocks.asp' \
		--header 'User-Agent:  Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Safari/537.36' \
		--header 'X-Requested-With:  XMLHttpRequest' \
		--data-urlencode 'connect_action=Reconnect'
		echo "$(date "+%Y-%m-%d %H:%M:%S") 【UPDATE】设置新节点成功，节点编号： $port" >> /etc/storage/logs/ssr_updateport.log
	fi
}

# MainStart
/usr/bin/ss-check www.youtube.com 80 3 1
check=$?
if [ "$check" == "0" ]; then
	echo "$(date "+%Y-%m-%d %H:%M:%S") 【Success】Check YouTube Proxy Pass." >> /etc/storage/logs/ssr_updateport.log
	break
else
	echo "$(date "+%Y-%m-%d %H:%M:%S") 【ERROR】Check YouTube Proxy Fail. 触发ping全部节点" >> /etc/storage/logs/ssr_updateport.log
	#请求头中的 Authorization 可以在浏览器登录一次路由器后获取到（开发者调试工具中）
	curl --location --request POST 'http://172.19.56.1/applydb.cgi?useping=1&p=ss' \
	--header 'Accept:  text/plain, */*; q=0.01' \
	--header 'Accept-Encoding:  gzip, deflate' \
	--header 'Accept-Language:  zh-CN,zh;q=0.9' \
	--header 'Authorization:  Basic YWRtaW46Q2xpbmcqMDAwMDA=' \
	--header 'Connection:  keep-alive' \
	--header 'Content-Length:  9' \
	--header 'Content-Type: application/x-www-form-urlencoded' \
	--header 'DNT:  1' \
	--header 'Host:  172.19.56.1' \
	--header 'Origin:  http://172.19.56.1' \
	--header 'Referer:  http://172.19.56.1/Shadowsocks.asp' \
	--header 'User-Agent:  Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Safari/537.36' \
	--header 'X-Requested-With:  XMLHttpRequest' \
	--data-urlencode '1=allping'
	#1分钟后获取Ping结果
	sleep 60
	get_allssr
fi
exit 0  	
