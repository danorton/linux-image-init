#!/bin/bash
set -e
#yu di efs
# <UDF name="WEIRD_NEW_HOSTNAME" Label="Hostname" />
# <UDF name="WEIRD_FETCH_URL"  Label="URL for fetching init data" />
# <UDF name="WEIRD_LAN_IPV4"  Label="Private IPv4/mask" />

# Log file for this script
logfile=/var/log/linux-init-script.log
# stage 2 script file
stage2file=/tmp/linux-init-stage2.sh

if [ "$WEIRD_LAN_IPV4" ]; then
  export WEIRD_LAN_IPV4_IP=${WEIRD_LAN_IPV4///*}
  export WEIRD_LAN_IPV4_MASK=${WEIRD_LAN_IPV4##*/}
fi

# Update the latest list of packages
apt-get -qy update
# We need "ts" for our log output
apt-get -qy install moreutils

# create a script file
curl -sSo "$stage2file" "$WEIRD_FETCH_URL/init-stage2"

# run the script we just fetched and log its output
bash "$stage2file" 2>&1 | ts '%Y-%m-%d %H:%M:%.S%z' >> $logfile
echo "Script completed successfully" 2>&1 | ts '%Y-%m-%d %H:%M:%.S%z' >> $logfile

# delete our selfsame script
rm -vf "$0" 2>&1 | ts '%Y-%m-%d %H:%M:%.S%z' >> $logfile

# Shut down (Triggers a Lassie watchdog reboot)
echo "Shutting down (triggers Lassie reboot)" 2>&1 | ts '%Y-%m-%d %H:%M:%.S%z' >> $logfile
shutdown -hP now 2>&1 | ts '%Y-%m-%d %H:%M:%.S%z' >> $logfile

