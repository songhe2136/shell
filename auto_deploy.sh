1.批量自动部署和回滚.
(结合jenkins ，可以引用jenkins的变量优化脚本)

#!/bin/bash
# Code Env

pro_name="adore_api"

code_dir="/deploy/code/$pro_name"
source_dir="/deploy/source_code/$pro_name"
web_dir="/data/spring_boot"
tmp_dir="/deploy/tmp"
backup_dir="/data/backup/$pro_name"
deploy_dir="/deploy"

# Node List
#pre_list="10.10.3.8"
group_list="spring@10.10.3.26 spring@10.10.3.27 spring@10.10.3.28"
rollback_list="spring@192.168.2.26 spring@192.168.2.27 spring@192.168.2.28"

# Date Varibles
ctime=$(date "+%F-%H-%M")

# Shell Env
shell_name="deploy_adore_api.sh"
shell_dir="/deploy/bin"

# Deploy Log
log_file="${deploy_dir}/log/${shell_name}".log
lock_file="${deploy_dir}/var/${pro_name}-deploy.lock"

set -x 
# Shell Lock
shell_lock () {
    touch ${lock_file}
} 
shell_unlock () {
    rm -f ${lock_file}
}

# Deploy logs
write_log () {
    loginfo=$1
    echo "${ctime}:${shell_name}:${loginfo}" >> ${log_file}
}

# Code Flow
code_get () {
    write_log "code_get"
    cd ${source_dir}
      #git_cid=$(svn log|awk 'NR==2{print $1}')
      git_cid=$(git log|awk 'NR==1{print $2}'|cut -c 1-6)
      pkg_version="${ctime}_${git_cid}"
      pkg_name="${pro_name}_${pkg_version}"
      cp -r ${source_dir} ${tmp_dir}/${pkg_name}
    write_log "code_get succeed!"
}
 
code_build () {
    write_log "code_build"
    cd ${tmp_dir}/${pkg_name}
      #/home/gradle/bin/gradle clean build
      cp build/libs/${pro_name}.jar ${code_dir}
      cd ${code_dir} && mv ${pro_name}.jar ${pkg_name}.jar
      write_log "${pkg_name}.jar"
    write_log "code_build succeed!"
}

code_scp () {
    write_log "code_scp"
    for node in $group_list;do
    	scp "${code_dir}/${pkg_name}.jar" $node:"${backup_dir}"
        write_log "scp $node ${pro_name}"
    done
    write_log "code_scp succeed!"
}

group_deploy () {
    write_log "code_deploy"
    for node in $group_list;do
        ssh $node "/data/spring_boot/adore_api/log/jstack.sh;cd ${web_dir}/${pro_name} && rm -f ${pro_name}.jar && ln -s ${backup_dir}/${pkg_name}.jar ${pro_name}.jar"
        ssh $node "${web_dir}/bin/service.sh ${pro_name} stop >/dev/null;sleep 1"
        ssh $node "${web_dir}/bin/service.sh ${pro_name} start >/dev/null;sleep 8"
        pid=`ssh $node ps -ef|grep ${pro_name}|grep -v grep|awk '{print $2}'`;
        if [ -z "$pid" ] || [ "$pid" -le 0 ]; then echo "service ${pro_name} Failed";shell_unlock; exit 1;fi
        write_log "restart_server $node ${pro_name}"
    done
    write_log "code_deploy succeed!"
}

# Rollback Code
rollback_list () {
    for node in $group_list;do
        ssh $node ls -itchl ${backup_dir}|awk '{print $NF}'|sed 1d|head -n5;echo $node
    done
}

rollback_fun () {
    write_log "rollback_code"
    if [ -z $rollback ];then
        shell_unlock;
        echo "Please input rollback version" && exit
    else
        for node in $rollback_list;do
            ssh $node "cd ${web_dir}/${pro_name} && rm -f ${pro_name}.jar && ln -s ${backup_dir}/$rollback ${pro_name}.jar"
            ssh $node "${web_dir}/bin/service.sh ${pro_name} stop >/dev/null;sleep 1"
            ssh $node "${web_dir}/bin/service.sh ${pro_name} start >/dev/null;sleep 5"
            pid=`ssh $node ps -ef|grep ${pro_name}|grep -v grep|awk '{print $2}'`;
            if [ -z "$pid" ] || [ "$pid" -le 0 ]; then echo "service ${pro_name} Failed";shell_unlock; exit 1;fi
            write_log "rollback_code $node restart ${pro_name} "
        done
    fi
    write_log "rollback_code succeed!"
}

#####

chk_deploy_log () {
    more /deploy/log/${shell_name}.log|grep $ctime
}
chk_rollback_log(){
    more /deploy/log/${shell_name}.log|grep $ctime
}

####

# Main Method
main () {
    if [ -f "$lock_file" ];then
      echo "Deploy is Running" && exit;
    fi
    deploy_method="$1"
    rollback="$2"
    case $deploy_method in
      deploy)
          shell_lock;
          code_get;
          code_build;
          code_scp;
          group_deploy;
          shell_unlock;
          chk_deploy_log;
          ;; 
      list)
          rollback_list;
          ;;
      rollback)
          shell_lock;
          rollback_fun $rollback;
          shell_unlock;
          chk_rollback_log;
      ;;
      *)
          echo "$Usage:$0 [ deploy | list | rollback ]"
      esac
}
main $1 $2 


2.自动删除部署历史包，保留最近7次部署。
#!/bin/bash
# Del and backup deploy version
#Usage sh $0 pro_name

tmp_var=$1

del_and_backup () {
    for project in `ls /$dir/backup/`;do
        cd /$dir/backup/$project
        pkg_count=`ls|wc -l`
	if [ $pkg_count -ge 8 ];then
            del_history_count=`expr $pkg_count - 7`
            ls|head -n $del_history_count|xargs rm -rf
        fi
    done        
}

if [ -z ${tmp_var} ];then echo "Usage:$0 [error. No parameter!]";exit;fi
if [ ${tmp_var} = adoreapp ];then dir="data";del_and_backup;fi
if [ ${tmp_var} = konglongbao ];then dir="home";del_and_backup;fi
if [ ${tmp_var} = qingchifan ];then dir="home";del_and_backup;fi
if [ ${tmp_var} = maoqiuapp ];then dir="home";del_and_backup;fi


3.自动删除jenkins 服务器 build 包
#!/bin/bash
# Del and backup deploy version
#Usage sh $0 pro_name

tmp_var=$1

del_and_backup () {
    for project in `ls /deploy/$dir`;do
        cd /deploy/$dir/$project
        pkg_count=`ls|wc -l`
        if [ $pkg_count -ge 30 ];then
            del_history_count=`expr $pkg_count - 29`
            ls|head -n $del_history_count|xargs rm -rf
        fi
    done        
}

del_and_backup2 () {
cd /deploy/$dir
pkg_count=`ls|wc -l`
if [ $pkg_count -ge 30 ];then
    del_history_count=`expr $pkg_count - 29`
    ls|head -n $del_history_count|xargs rm -rf
fi
}

if [ -z ${tmp_var} ];then echo "Usage:$0 [error. No parameter!]";exit;fi
if [ ${tmp_var} = "build_code_pkg" ];then dir="code";del_and_backup;fi
if [ ${tmp_var} = "tmp_build_code_pkg" ];then dir="tmp";del_and_backup2;fi
