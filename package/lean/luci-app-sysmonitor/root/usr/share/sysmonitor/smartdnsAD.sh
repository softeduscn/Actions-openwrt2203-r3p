#!/bin/sh

AD_PATH=/tmp/anti-ad-for-smartdns.conf
SM_AD_PATH=/etc/smartdns/anti-ad-smartdns.conf

if [ -f "$SM_AD_PATH" ]; then
docp=0
/bin/rm -f $AD_PATH
if wget -q -P /tmp https://anti-ad.net/anti-ad-for-smartdns.conf; then
  if cmp -s $SM_AD_PATH $AD_PATH; then
    /bin/rm -f $AD_PATH
    exit 0
  elif [ -s $AD_PATH ]; then
    /bin/mv -f $AD_PATH $SM_AD_PATH
    docp=1
  else # download file size 0
    exit 1
  fi
fi

if [ $docp -eq 1 ]; then
  /etc/init.d/smartdns restart
fi
fi

