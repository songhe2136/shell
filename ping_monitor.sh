#!/bin/bash
#Adore subject
c_time=`date +"%F %T"`

#monitor ip
my_ip="
192.168.20.21 
192.168.20.22 
192.168.20.23 
"

#ping -c
check_ping () { 
for ip in ${my_ip};do
    num=1
    while [ $num -le 3 ];do
        if ping -c 1 $ip >/dev/null;then
            #echo "$ip ping is successful"
            break
        else
            ping_fail[$num]=$ip
            let num++
            sleep 2
        fi
    done
    if [ ${#ping_fail[@]} -eq 3 ];then
        echo "Adore ${c_time} {PROBLEM: Zabbix agent($ip) on Zabbix server is unreachable for 5 minutes}"| \ 
        mail -s "PROBLEM: Host is unreachable for 5 minutes" xxx@huiyoujia.com
        unset ping_fail[@]
    fi
done
}
check_ping
