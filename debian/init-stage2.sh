#!/bin/bash
set -e

# Allow public key for root ssh login
if [ ! -s /root/.ssh/authorized_keys ]; then
  mkdir -p /root/.ssh
  curl -sS "$WEIRD_FETCH_URL/linux/ssh_authorized_keys" >> /root/.ssh/authorized_keys
  chmod -R o-rwx /root/.ssh
fi

# Fix hostname and make it stick after reboot
if [ "$WEIRD_NEW_HOSTNAME" ]; then
  echo $WEIRD_NEW_HOSTNAME > /etc/hostname
  hostname -F /etc/hostname
fi
cat /etc/hostname > /etc/mailname
echo -e "g/^domain\>/d\n1i\ndomain weirdmasters.com\n.\nwq" \
  | ed resolv.conf \
 || true

# get rid of exim4 and fetch puppet
# we need "ed" for this selfsame script
apt-get -qyf install ed ssmtp bsd-mailx puppet

# Don't let puppet interfere during our init
service puppet stop

# Upgrade packages that had already been installed
apt-get -qy upgrade
apt-get -qy dist-upgrade

# get rid of cached packages
apt-get -qy --purge autoremove
dpkg --get-selections \
  | sed -ne 's/[\t]*deinstall//p' \
  | xargs dpkg --purge \
 || true

# Add Private IP address
if [ "$WEIRD_LAN_IPV4" ]; then
  WEIRD_LAN_IPV4_IP=${WEIRD_LAN_IPV4///*}
  WEIRD_LAN_IPV4_MASK=${WEIRD_LAN_IPV4##*/}
  cat << __EOF__ >> /etc/network/interfaces

# Private IP address
auto eth0:1
iface eth0:1 inet static
    address $WEIRD_LAN_IPV4_IP
    netmask $WEIRD_LAN_IPV4_MASK
__EOF__
fi

# Get basic but non-standard puppet functions
mkdir -p /var/lib/puppet/lib/facter
curl -sSo /var/lib/puppet/lib/facter/meminbytes.rb \
     "$WEIRD_FETCH_URL/puppet/facter/meminbytes.rb"

# Add puppet agent configuration
cat << __EOF__ >> /etc/puppet/puppet.conf
[agent]
server = $WEIRD_PUPPET_MASTER
listen = true
__EOF__

# allow master to control this slave
cat << __EOF__ >> /etc/puppet/auth.conf
# Allow master to control us
path    /run
method  save
auth    any
allow   $WEIRD_PUPPET_MASTER
__EOF__

# start puppet at next (and every) boot
echo -e "1,\$s/START=no/START=yes/\nwq" | ed /etc/default/puppet \
 || true

# Our initial set of aliases for new accounts
curl -sSo /etc/skel/.bash_aliases \
     "$WEIRD_FETCH_URL/linux/skel/.bash_aliases"

# re-init root account with updated skeleton files
cp /etc/skel/.profile \
   /etc/skel/.bash_aliases \
   /etc/skel/.bashrc \
 /root/

# disable root password if we have a public key
if [ -s /root/.ssh/authorized_keys ]; then
  echo -e "1,\$s/^root:[^:]*:/root:\!:/\nwq" | ed /etc/shadow
fi

# clean up
rm -vf "$0"
