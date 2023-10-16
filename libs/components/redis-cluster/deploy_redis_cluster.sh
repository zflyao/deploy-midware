#!/bin/bash
# redis cluster deploy
# Attention:
#   1、The mounted directory must belong to 1001
#   2、The IPs should be supplied.
#   3、Default port is 6379
#   4、use image： bitnami/redis-cluster-fix:5.0.14
deply_dir="/home/gdapp/test_redis"

# 部署节点ip和port, port缺省为6379
host_port0=(${dynamic_redis_cluster1_ip[@]})
host_port1=(${dynamic_redis_cluster2_ip[@]})
host_port2=(${dynamic_redis_cluster3_ip[@]})
host_port3=(${dynamic_redis_cluster4_ip[@]})
host_port4=(${dynamic_redis_cluster5_ip[@]})
host_port5=(${dynamic_redis_cluster6_ip[@]})

REDIS_NODES="${host_port0[0]}:${host_port0[1]:-6379} ${host_port1[0]}:${host_port1[1]:-6379} \
${host_port2[0]}:${host_port2[1]:-6379} ${host_port3[0]}:${host_port3[1]:-6379} \
${host_port4[0]}:${host_port4[1]:-6379} ${host_port5[0]}:${host_port5[1]:-6379}"

IMAGE="bitnami/redis-cluster-fix:5.0.14"
# 认证密码
REDIS_PASSWORD="${REDIS_PASSWORD:-Gd@123}"
# 数据目录挂载路径
data_dir="${REDIS_DATA_DIR:-./data}"

# 单机还是多台，0:单机; 1:多台
mode=1


create_dir(){
    if [ -d ${1} ];then
        mv ${1} ${1}-`date +%s`
    fi
    mkdir -p ${1}
    [ $? -eq 0 ] && return 0 || return 1
}


# 检查挂载目录权限1001
check_data_dir(){
    create_dir ${1}
    if [ $? -ne 0 ];then
        echo "数据挂载目录创建失败，请检查权限..."
        exit
    else
                pwd
        echo "数据挂载目录创建SUCC..."
                chown 1001.1001 ${1}
    fi
}


make_compose_file(){

    # part 1
    cat >> docker-compose.yml <<EOF
version: '2'
services:
EOF
    # part 2
    host=host_port${1}[0]
    port=host_port${1}[1]
    cat >> docker-compose.yml <<EOF
  redis${i}:
    image: ${IMAGE}
    restart: always
    container_name: redis${i}
    volumes:
      - ./data${i}:/bitnami/redis/data
    environment:
      - 'REDIS_PORT_NUMBER=${!port:-6379}'
      - 'REDIS_PASSWORD=${REDIS_PASSWORD}'
      - 'REDIS_NODES=${REDIS_NODES}'
EOF
    if [ ${1} -eq 5 ];then
        cat >> docker-compose.yml <<EOF
      - 'REDIS_CLUSTER_REPLICAS=1'
      - 'REDIS_CLUSTER_CREATOR=yes'
      - 'REDISCLI_AUTH=${REDIS_PASSWORD}'
EOF

    fi
    if [ "${mode}" != "0" ];then
        cat >> docker-compose.yml <<EOF
      - 'REDIS_CLUSTER_DYNAMIC_IPS=no'
      - 'REDIS_CLUSTER_ANNOUNCE_IP=${!host}'
    network_mode: 'host'
EOF
    fi

}


main(){

    while :
    do
        count=0
        for n in ${REDIS_NODES[@]}
        do
            echo -e "\t${count} ) $n"
            (( count += 1 ))
        done
        read -p "请输入部署节点[0-5]: " node
        if [ -z $node ];then
            echo "没有输入节点号"
        else
           break
        fi
    done

    full_dir=${deply_dir}${node}
    mkdir -p ${full_dir}
    cd ${full_dir}
    check_data_dir ${data_dir}

    if [ -f docker-compose.yml ];then
        mv docker-compose.yml docker-compose.yml-`date +%s`
    fi

    make_compose_file ${node}
    num=$(docker images |grep "${IMAGE}"|wc -l)
    if [ $num -lt 1 ];then
        echo "    配置文件已经生成：${full_dir}"
        echo "    请上传Redis镜像: ${IMAGE}"
        exit 5
    fi
    command=$(which docker-compose)
    if [ -z ${command} ];then
        command='docker compose '
    fi
    ${command} up -d

}

main

