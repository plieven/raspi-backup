#!/bin/bash
set -e
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
err() { echo "ERR: $@" 1>&2; exit 1; }
[ "$(id -u)" != "0" ] && err "This script must be run as root!"
[ -e /etc/default/raspi-backup ] && . /etc/default/raspi-backup
[ -z $LIBDIR ] && LIBDIR=/var/lib/raspi-backup
[ -z $SSHKEY ] && SSHKEY=/etc/ssh/ssh_host_ed25519_key
[ -z $RSYNCFLAGS ] && RSYNCFLAGS="-azHSx --delete -M--fake-super --numeric-ids"

#prechecks
[ ! -e /dev/mmcblk0 ] && err "Device /dev/mmcblk0 not found!"
[ ! -e /dev/mmcblk0p1 ] && err "Partition /dev/mmcblk0p1 not found!"
[ ! -e /dev/mmcblk0p2 ] && err "Partition /dev/mmcblk0p2 not found!"
[ $(grep mmcblk0p /proc/partitions | wc -l) -ne 2 ] && err "Unexpected number of partitions on /dev/mmcblk0!"
[ $(blkid -c /dev/null -o value -s TYPE /dev/mmcblk0p1) != "vfat" ] && err "/dev/mmcblk0p2 has not fstype vfat!"
[ $(blkid -c /dev/null -o value -s TYPE /dev/mmcblk0p2) != "ext4" ] && err "/dev/mmcblk0p2 has not fstype ext4!"

[ -n "$CHECK" ] && exit 0

#checks
[ -z $BACKUPHOST ] && err "No BACKUPHOST defined in /etc/default/raspi-backup!"  
[ -z $CLIENT ] && err "No CLIENT defined in /etc/default/raspi-backup!"

[ -z $SILENT ] && echo "Staring Backup of /dev/mmcblk0 to $BACKUPHOST"
mkdir -p $LIBDIR
START=$(date +%s)
[ -z $SILENT ] && echo "Backing up Root Filesystem..."
rsync $RSYNCFLAGS -e "ssh -i $SSHKEY" --exclude=/tmp --exclude=$LIBDIR / $CLIENT@$BACKUPHOST:/
[ -z $SILENT ] && echo "Backing up Boot Partition..."
rsync $RSYNCFLAGS -e "ssh -i $SSHKEY" /boot/ $CLIENT@$BACKUPHOST:/boot/
[ -z $SILENT ] && echo "Backing up Metadata..."
blockdev --getsize64 /dev/mmcblk0 >$LIBDIR/mmcblk0.size
dd if=/dev/mmcblk0 of=$LIBDIR/mmcblk0.bootsector bs=512 count=1 2>/dev/null
uptime -p >$LIBDIR/uptime
uname -r >$LIBDIR/kernel
hostname -f >$LIBDIR/hostname
ip route get 1 | awk '{print $NF;exit}' >$LIBDIR/clientip
blkid -c /dev/null -o value -s UUID /dev/mmcblk0p1 >$LIBDIR/mmcblk0p1.uuid
blkid -c /dev/null -o value -s UUID /dev/mmcblk0p2 >$LIBDIR/mmcblk0p2.uuid
blkid -c /dev/null -o value -s TYPE /dev/mmcblk0p1 >$LIBDIR/mmcblk0p1.fstype
blkid -c /dev/null -o value -s TYPE /dev/mmcblk0p2 >$LIBDIR/mmcblk0p2.fstype
blockdev --getsize64 /dev/mmcblk0p1 >$LIBDIR/mmcblk0p1.size
blockdev --getsize64 /dev/mmcblk0p2 >$LIBDIR/mmcblk0p2.size
df  -B1 --output=used / | tail -1 >$LIBDIR/mmcblk0p2.used
df  -B1 --output=used /boot | tail -1 >$LIBDIR/mmcblk0p1.used
ntptrace -m 1 >$LIBDIR/ntptrace
END=$(date +%s)
echo $END >$LIBDIR/BACKUPDATE
echo $((END-START)) >$LIBDIR/BACKUPDURATION
rsync $RSYNCFLAGS -e "ssh -i $SSHKEY" $LIBDIR/ $CLIENT@$BACKUPHOST:$LIBDIR
END=$(date +%s)
[ -z $SILENT ] && echo "DONE in $((END-START)) seconds!"
