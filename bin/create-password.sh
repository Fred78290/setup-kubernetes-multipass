#!/bin/bash
KUBERNETESPWD_FILE="$HOME/.kubernetes_pwd"
OSNAME=`uname -s`

if [ -f $KUBERNETESPWD_FILE ] ; then
	KUBERNETES_PASSWD=`cat $KUBERNETESPWD_FILE`
else

	if [ $OSNAME = "Darwin" ] ; then
		KUBERNETES_PASSWD=`date | md5sum -s | sed -e "s/ .*$//"`
	else
		KUBERNETES_PASSWD=`date | md5sum | sed -e "s/ .*$//"`
	fi
	
	echo -n $KUBERNETES_PASSWD > $KUBERNETESPWD_FILE
fi

export KUBERNETES_PASSWD

echo -n $KUBERNETES_PASSWD
