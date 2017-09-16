#!/bin/bash

LASTDTPID=1
COUNT=0
while :;
do
	DTPID=`ps ux | grep "/usr/bin/perl -w ./ed-devtracker-collector.p[l]" | awk '{print $2;}'`
	if [ ! -z ${DTPID} ];
	then
		#echo "`date` - Found in ps output"
		if [ ${DTPID} -ne ${LASTDTPID} ];
		then
			COUNT=1
			#echo "`date` - New PID: ${DTPID}"
			LASTDTPID=${DTPID}
		else
			COUNT=`expr ${COUNT} + 1`
			#echo "`date` - Old PID, count now: ${COUNT}"
			if [ ${COUNT} -gt 10 ];
			then
				echo "`date` - Killing process ${DTPID} at count ${COUNT}"
				kill ${DTPID}
			fi
		fi
		#date ; lsof -p ${DTPID} | grep aws
	fi
	sleep 60
done
