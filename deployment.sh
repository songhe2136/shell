# 该 shell 结合 jenkins 执行构建动作 自动发布应用到 k8s 集群。用到的相关组件：jenkins,gitlab,harbor,k8s，nexue
# shell 脚本注释也比较清晰，一目了然。

#!/bin/bash
# Code Env
set -e
# Date Varibles
ctime=$(date "+%F-%H-%M")

# Shell Env
shell_name="$0"
shell_dir="${JENKINS_HOME}/deploy"

# Deploy Log
log_file="${shell_name}".log
log_tag="${ctime} ${JOB_NAME}:"
lock_file="${shell_dir}/var/${shell_name}.lock"

# Docker Registry 
registry_url="hub.abc.com"
repository_name="public/${JOB_NAME}"

# Shell Lock
shell_lock () {
    touch ${lock_file}
} 
shell_unlock () {
    rm -f ${lock_file}
}

# Deploy Logs
write_log () {
    loginfo=$1
    echo "${ctime}:${shell_name}:${loginfo}" >> ${log_file}
}

# Docker Build Image
docker_build () {
    echo -e "\n[[Stage 1.]]\n## docker_build staring... It may take you a few seconds, please wait... \
    \nThe branch you choose is ${Branch}"
    write_log "${log_tag} docker_build staring..."
    cd ${WORKSPACE}
    git_cid=$(git log|awk 'NR==1{print $2}'|cut -c 1-6)
    if [ -f Dockerfile ];then
        docker build -t ${registry_url}/${repository_name}:${ctime}_${git_cid} . >>/dev/null
        if [ $? = 0 ];then
            echo "## docker_build ending!  ${registry_url}/${repository_name}:${ctime}_${git_cid}"
            write_log "${log_tag} docker_build ending!"
        else
            echo "## err[1001]: docker_build failed! It may be that Dockerfile exec has a problem."
            write_log "${log_tag} err[1001]: docker_build failed! It may be that Dockerfile exec has a problem."
            exit 1
        fi
    else
        echo "## err[1002]: The Dockerfile is not exist! Please upload your Dockerfile."
        write_log "${log_tag} err[1002]: The Dockerfile is not exist! Please upload your Dockerfile."
        exit 1
    fi
}
# Docker push image to harbor
docker_push () {
    echo -e "\n[[Stage 2.]]\n## docker_push starting... It may take you a few seconds, please wait..."
    write_log "${log_tag} docker_push starting..."
    if docker images|grep "${ctime}_${git_cid}";then
        docker push ${registry_url}/${repository_name}:${ctime}_${git_cid} >>/dev/null
        if [ $? = 0 ];then
            echo "## docker_push ending!"
            write_log "${log_tag} docker_build ending!"
        else
            echo "## err[1003]: docker_push failed! It could be that the network is unreachable or \ 
            No privileges to access this repository."
            write_log "${log_tag} err[1003]: docker_push failed! It could be that the network is unreachable or \
            No privileges to access this repository"
            exit 1
        fi
    else 
        echo "## err[1004]: The image is not exist! It may have a problem with your image build, \
        You should check [[Stage 1.]]"
        write_log "${log_tag} err[1004]: The image is not exist! It may have a problem with your image build, \
        You should check [[Stage 1.]]"
        exit 1
    fi
}

deploy_RollingUpdate () {
    echo -e "\n[[Stage 3.]]\n## docker_RollingUpdate starting..."
    kubecli="${shell_dir}/bin/kubectl"
    deploy_name=`echo ${JOB_NAME}|sed  s/_/-/g`
    if ${kubecli} get deploy|grep ${deploy_name};then
        ${kubecli} set image deploy ${deploy_name} lianjinshu-api=${registry_url}/${repository_name}:${ctime}_${git_cid} --record
        if [ $? = 0 ];then
            sleep 6;
            echo -e "## deploy_RollingUpdate ending!\n`${kubecli} describe deploy lianjinshu-api|grep "Image:\|Replicas:"|sort`\n"
            write_log "${log_tag} deploy_RollingUpdate ending!\n`${kubecli} describe deploy lianjinshu-api|grep "Image:\|Replicas:"|sort`"
        else
            echo "## err[1005]: Waring! deploy_RollingUpdate failed! The problem needs to be solved as soon as possible."
            write_log "${log_tag} Waring! deploy_RollingUpdate failed! The problem needs to be solved as soon as possible."
            exit 1
        fi
    else
        echo " ## err[1006]: The deploy is not exist!,please check..."
        write_log "${log_tag} err[1006]: The deploy is not exist!,please check..."
        exit 1
    fi
}

# main func
main () {
    if [ -f "$lock_file" ];then
        echo "## The deploy is Running" && exit 1;
    else
        docker_build && docker_push && deploy_RollingUpdate && shell_unlock
    fi
}

main
set +e



下面是从jenkins  Console Output截取的一段 效果图 ：

Total time: 9.345 secs
Build step 'Invoke Gradle script' changed build result to SUCCESS
[lianjinshu_api] $ /bin/sh -xe /tmp/jenkins6507607136618008479.sh
+ /var/jenkins_home/deploy/bin/deployment.sh

[[Stage 1.]]
## docker_build staring... It may take you a few seconds, please wait...     
The branch you choose is origin/master
## docker_build ending!  hub.abc.com/public/abc_api:2018-07-14-19-33_128809

[[Stage 2.]]
## docker_push starting... It may take you a few seconds, please wait...
hub.abc.com/public/abc_api   2018-07-14-19-33_128809   6f82012f5050        Less than a second ago   960MB
## docker_push ending!

[[Stage 3.]]
## docker_RollingUpdate starting...
abc-api   3         3         3            3           4d
deployment.apps "abc-api" image updated
## deploy_RollingUpdate ending!
    Image:      hub.abc.com/public/abc_api:2018-07-14-19-33_128809
Replicas:               3 desired | 2 updated | 4 total | 2 available | 2 unavailable

Finished: SUCCESS

