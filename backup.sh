#!/bin/bash

# backup the primary server image to external disk using LVM snapshot and sparsify with qemu-img
# Jason Shaw
#
# MIT License
# 
# Copyright (c) [year] [fullname]
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
# Assumptions
# - on file system, image is named $SERVER.img
# - on file system, image lives in images directory under mount point

# variables
SERVER=atom
LV_SERVER=/dev/vg_relucent/lv_servers
LV_SNAPSHOT=/dev/vg_relucent/lv_snapshot
LV_SNAPSHOT_SIZE=10G
LOG=/var/log/snapshot.log
MP_BACKUP=/backup
MP_SNAPSHOT=/servers/snapshot
# days, should leave 3 copies at any one time
RETENTION_PERIOD=15

##### no more settings


# make sure MP_BACKUP is mounted
/bin/mountpoint -q $MP_BACKUP
if [ $? -gt 0 ]; then
        # try to mount it
        /bin/mount $MP_BACKUP
        if [ $? -ne 0 ]; then
                # didn't mount, puke
                echo "`date +'%b %d %H:%M:%S'`: mountpoint $MP_BACKUP not available, investigate" >> $LOG
                exit 1
        fi
fi

# make sure the snapshot isn't already there
snaplv=`echo $LV_SNAPSHOT|awk -F\/ '{print $4}'`
check=`/sbin/lvs|grep $snaplv | wc -l`
if [ $check -ge 1 ]; then
        echo "`date +'%b %d %H:%M:%S'`: snapshot already exists, investigate" >> $LOG
        # eventually send an email here
        exit 1
fi

# take the snapshot, mount it
echo "`date +'%b %d %H:%M:%S'`: lvcreate -L $LV_SNAPSHOT_SIZE -s -n $snaplv $LV_SERVER" >> $LOG
/sbin/lvcreate -L $LV_SNAPSHOT_SIZE -s -n $snaplv $LV_SERVER
echo "`date +'%b %d %H:%M:%S'`: mount -o nouuid $LV_SNAPSHOT $MP_SNAPSHOT" >> $LOG
/bin/mount -o nouuid $LV_SNAPSHOT $MP_SNAPSHOT


# make sure the images directory is available (i.e. it isn't a blank disk)
timestamp=`date +'%m.%d.%y'`
if [ ! -d ${MP_BACKUP}/images ]; then
        /bin/mkdir ${MP_BACKUP}/images
        echo "`date +'%b %d %H:%M:%S'`: mkdir ${MP_BACKUP}/images" >> $LOG
fi

# at this point, we're pretty sure we can copy off the snapshot so free up some space on $MP_BACKUP
echo "`date +'%b %d %H:%M:%S'`: /usr/bin/find $MP_BACKUP/images -mtime +${RETENTION_PERIOD} -print -exec rm -f {} \;" >> $LOG
/usr/bin/find $MP_BACKUP/images -mtime +${RETENTION_PERIOD} -print -exec rm -f {} \;

# copy the snapshot off and sparsify
echo "`date +'%b %d %H:%M:%S'`: qemu-img convert -O qcow2  ${MP_SNAPSHOT}/images/${SERVER}.img ${MP_BACKUP}/images/${SERVER}.${timestamp}.img" >> $LOG
/usr/bin/qemu-img convert -O qcow2  ${MP_SNAPSHOT}/images/${SERVER}.img ${MP_BACKUP}/images/${SERVER}.${timestamp}.img

# unmount and remove the snapshot
echo "`date +'%b %d %H:%M:%S'`: umount $MP_SNAPSHOT" >> $LOG
/bin/umount $MP_SNAPSHOT
echo "`date +'%b %d %H:%M:%S'`: lvremove -f $LV_SNAPSHOT" >> $LOG
/sbin/lvremove -f $LV_SNAPSHOT

# dump the xml file for the guest
echo "`date +'%b %d %H:%M:%S'`: virsh dumpxml $SERVER >> ${MP_BACKUP}/images/${SERVER}.${timestamp}.xml" >> $LOG
/usr/bin/virsh  dumpxml $SERVER >> ${MP_BACKUP}/images/${SERVER}.${timestamp}.xml
