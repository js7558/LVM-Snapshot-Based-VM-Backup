# LVM-Snapshot-Based-VM-Backup
Backup script that uses LVM snapshots to back up a VM running on KVM and reclaims space in the backed up image.   Written/tested on Ubuntu 14.04 LTS with qcow2 based Ubuntu VMs running on KVM.

Modify variables under the #variables section to suit your deployment. 

Probably a good idea to test the backup you get from this script to make sure it works in your environment.  It has been working well in my customer's environment for a few years.   We normally back up to a USB attached hard drive that we rotate offsite each month.

Running this weekly in cron on a customer system as follows (script name includes the name of the server since we had several).

0 0 * * 3 /servers/scripts/backup.atom.sh

Please let me know if you find any issues with it and I'll work in corrections. 
