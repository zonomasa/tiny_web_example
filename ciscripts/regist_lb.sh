#!/bin/bash

#############################################
# usage : ./this.sh parameter_file num_of_web_server
#############################################

# load-balancer に登録されているVIF をクリーンアップした後、
# $1 で渡されるファイルに記載のWeb サーバーのVIF を登録する。
# 期待するファイルのフォーマット：
#    ・"WEB {instance id} {ip address}" が1行以上存在すること
#    ・接頭語が"WEB" 以外の行については読みとばすため制限は無い
#
#
# ※本スクリプトはintegration-test 用なので以下の点で本番運用向けとは異なる。
#    ・起動時に登録されているVIFはすべて削除する
#    ・load-balancer はすでに起動されているものとし、instance id も
#      静的に決定され本スクリプトに記述されているものとする

set -exu
set -o pipefail

FILE=$1
NUM=$2  # Web サーバの数

# load-balancer のinstance id
# 将来的にload-balancer の動的起動を行う場合は、
# instance id も取得するよう変更すべきである。
LB_ID=lb-mkuhkuv3

# envs for mussel
export DCMGR_HOST=10.0.2.2
export account_id=a-shpoolxx
. /etc/.musselrc


# load-balancer に登録されているすべてのVIF を掃除する
function clean_lb(){
    set +e
    tmp=`mussel load_balancer show ${LB_ID} |grep network_vif_id |awk '{print $3}'`
    set -e
    for vif in $tmp
    do
        echo "[CISCRIPT] Delete ${vif} from load balancer(${LB_ID})"
        mussel load_balancer unregister ${LB_ID} --vifs ${vif} >/dev/null
    done
}

# load-balancer に新たにVIF を頭足する
function regist_lb(){
    while read LINE;
    do
#        echo $LINE
        if [ -n "`echo $LINE | grep 'WEB'`" ] ; then
            ID=`echo $LINE|awk '{print $2}'`
            IP=`echo $LINE|awk '{print $3}'`
            VIF=`mussel instance show ${ID}|grep :vif_id|awk '{print $3}'`
            echo "[CISCRIPT] Add ${VIF} to load balancer(${LB_ID})"
            mussel load_balancer register ${LB_ID} --vifs ${VIF} >/dev/null
        fi
    done <$FILE
}


# load-balancer に登録されているVIF 数が$NUM と等しいかを確認する
function check_lb(){
    if [ `mussel load_balancer show ${LB_ID} |grep network_vif_id |awk '{print $3}'|wc -l` -ne ${NUM} ] ;then
        echo "[CISCRIPT] Checking Load balancer failed"
        exit 1
    fi
}

function main(){
    clean_lb
    regist_lb
    # mussel load_balancer show ${LB_ID}
    check_lb
}

main
