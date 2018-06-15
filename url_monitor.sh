#/bin/bash

c_time=`date +"%F %T"`

#monitor url
qingchifan_url="
http://www.qingchifan.com/a
http://www.qingchifan.com/b
http://www.qingchifan.com/c
"
adore_url="
http://www.adoreapp.com/member1
http://www.adoreapp.com/member2
http://www.adoreapp.com/member3
"
maoqiu_url="
http://www.maoqiuapp.com/dashboard1
http://www.maoqiuapp.com/dashboard2
http://www.maoqiuapp.com/dashboard3
"
my_url="$qingchifan_url $adore_url $maoqiu_url"

check_url () {
for url in $my_url;do
    num=1
    while [ $num -le 3 ];do
        if [ `curl --connect-timeout 3 -o /dev/null -sw %{http_code} $url` -eq 200 ];then
            break
        else
            fail_url[$num]=1
            let num++
        fi
    done
    if [ ${#fail_url[@]} -eq 3 ];then
        echo "$c_time $url is access failed" >>/home/shell/url_monitor.log
        domain_name=`echo $url|cut -d '/' -f 3`
        if ping -c 1 -w 1000 $domain_name >>/dev/null;then
            echo "$c_time $domain_name ping is successful" >>/home/shell/url_monitor.log
        else
            echo "$c_time $domain_name ping is failed" >>/home/shell/url_monitor.log
        fi
        unset fail_url[@]
    fi
done

if [ -s /home/shell/url_monitor.log ];then
    /home/shell/mail "810485328@qq.com;zhangsonghe@huiyoujia.com" "url_monitor" "`cat /home/shell/url_monitor.log`"
fi  
>/home/shell/url_monitor.log
}

check_url 
