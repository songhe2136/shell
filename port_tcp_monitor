#!/bin/bash

date=`date "+%F %T"`
cd /home/shell/

chk_port () {
hostname="$1"
tomcat_port="$2"
tomcat_instance="$3"
    if nc -w 2 $hostname $tomcat_port;then
        continue
    else
        echo -e ""$date" \n"$hostname $tomcat_instance $tomcat_port"" >>tmp.txt
    fi
}

send_mail () {
    if [ -e tmp.txt ];then
        echo "Please check the service.">> tmp.txt
        ./mail "yyyy@qq.com;xxxx@qq.com" zhuaww "`cat /home/shell/tmp.txt`"
    fi
    rm -f tmp.txt
}

chk_port "192.168.20.12" "1081" "int.zhuaww.com";
chk_port "192.168.20.12" "8000" "devs.zhuaww.com";
chk_port "192.168.20.13" "1081" "int.zhuaww.com";
chk_port "192.168.20.13" "8001" "devs.zhuaww.com";
chk_port "192.168.20.14" "1083" "guan.zhuaww.com";

send_mail
