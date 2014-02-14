#!/bin/bash

#set nagios status
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

usage (){
        echo -en "Usage: $0 -d [ eth|bond ]\nFor example:\t$0 -d bond0\n" 1>&2
        exit ${STATE_WARNING}
}

while getopts w:c:d: opt
do
        case "$opt" in
		w)
			warning=$OPTARG
			warning_num=`echo "${warning}"|sed  's/%//g'`
		;;
		c)      
			critical=$OPTARG
			critical_num=`echo "${critical}"|sed  's/%//g'`
			check_num "${critical_num}"
		;;
        d) dev_id="$OPTARG";;
        *) usage;;
        esac
done

shift $[ $OPTIND - 1 ]

if [ -z "${dev_id}" ];then
        usage
fi

source_file='/proc/net/dev'
if [ ! -f "${source_file}" ];then
		echo "${source_file} not not exsit!" 1>&2
		exit ${STATE_WARNING}
fi

grep "${dev_id}" ${source_file} >/dev/null 2>&1 || dev_stat='not found'
if [ "${dev_stat}" = 'not found' ];then
		echo "${dev_id} ${dev_stat}!" 1>&2
		usage
fi

time_now=`date -d now +"%F %T"`
mark="/usr/local/nagios/libexec/net_traffic.${dev_id}"
info=`awk -F':|[ ]+' -v date="${time_now}"  'BEGIN{OFS=";"}/'${dev_id}'/{print "TIME=\""date"\"","RX="$3,"TX="$11,"DEV='${dev_id}'"}' "${source_file}"`

#debug
#eval "${info}"
#echo $info 
#echo $TIME $RX $TX && exit

if [ ! -f "${mark}" ];then
		echo "$info" > ${mark} || exit ${STATE_WARNING}
		chown nagios.nagios ${mark}
		echo "This script is First run! ${info}"
		exit ${STATE_OK}
else
		old_info=`cat ${mark}`
		eval "${old_info}"
		OLD_TIME="${TIME}";OLD_RX=${RX};OLD_TX=${TX}		
fi

if [ -n "${info}" ];then
		eval ${info}
		sec_now=`date -d "${TIME}" +"%s"`
		sec_old=`date -d "${OLD_TIME}" +"%s"`
		sec=`echo "${sec_now}-${sec_old}"|bc`
		rx=`echo "(${RX}-${OLD_RX})/${sec}"|bc`
		tx=`echo "(${TX}-${OLD_TX})/${sec}"|bc`
		echo "$info" > ${mark} || exit ${STATE_WARNING}
		chown nagios.nagios ${mark}
#		echo $sec $rx $tx
else
		echo "Can not read ${source_file}" 1>&2
		exit ${STATE_WARNING}
fi

human_read () {
local number="$1"
[ `echo "(${number}-1073741824) > 0"|bc` -eq 1 ] && output="`echo "scale=2;${number}/1024/1024/1024"|bc` GB/s"
[ `echo "(${number}-1048576) > 0"|bc` -eq 1 ]  && output="`echo "scale=2;${number}/1024/1024"|bc`MB/s"
[ `echo "(${number}-1024) >0"|bc` -eq 1 ] && output="`echo "scale=2;${number}/1024"|bc`KB/s" || output="${number} B/s"
echo "${output}"
}

rx_human_read=`human_read "${rx}"`
tx_human_read=`human_read "${tx}"`

message () {
    local stat="$1"
    echo "Net Traffic is ${stat} - RX: ${rx_human_read} TX: ${tx_human_read} interval: ${sec}s |RX=${rx};${warning};${critical};${min};${max} TX=${tx};;"
}

message "OK"
