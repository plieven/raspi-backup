#!/bin/bash -e
err() { echo "ERR: $@" 1>&2; exit 1; }
echo This will setup raspi-backup for daily backup of your Raspberry Pi!
echo
echo -n "Running prechecks... "
CHECK=1 bash ./raspi-backup.sh
echo DONE
echo
if [ -e /etc/default/raspi-backup ]; then
 . /etc/default/raspi-backup ]
else
 read -p 'Please enter Backupserver [raspi-backup.dlhnet.de]: ' BACKUPHOST
 read -p 'Please enter Client Name [raspiNNN]: ' CLIENT
 echo
fi
[ -z $BACKUPHOST ] && BACKUPHOST=raspi-backup.dlhnet.de
[ -z $CLIENT ] && err "No Client Name specified!"
TMPFILE=$(mktemp /tmp/raspi-backup-setup.XXXXXXXX)
[ -z $SSHKEY ] && SSHKEY=/etc/ssh/ssh_host_ed25519_key
echo -n "Checking connectivity to $BACKUPHOST... "
rsync -a -e "ssh -i $SSHKEY" $TMPFILE $CLIENT@$BACKUPHOST:/tmp/
echo OK
rm $TMPFILE
echo
echo Installing raspi-backup.sh to /usr/local/sbin/...
cp -v raspi-backup.sh /usr/local/sbin/
chmod 755 /usr/local/sbin/raspi-backup.sh
echo
echo Creating daily cronjob...
HOUR=$[ ($RANDOM % 23) ]
MINUTE=$[ ($RANDOM % 59) ]

CMDLINE="test -x /usr/local/sbin/raspi-backup.sh && /usr/local/sbin/raspi-backup.sh"

cat > /etc/cron.d/raspi-backup << EOF
$MINUTE $HOUR * * * root $CMDLINE
EOF
echo
echo Updating /etc/default/raspi-backup...
echo "BACKUPHOST=$BACKUPHOST" >/etc/default/raspi-backup
echo "CLIENT=$CLIENT" >>/etc/default/raspi-backup
echo
echo ALL DONE!
