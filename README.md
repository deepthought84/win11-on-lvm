# win11-on-lvm
Windows 11 on LVM (hack))
Boot Windows 11 from LVM on luks2 inside libvirt with GPU/USB-Passthrough.

Why? I find LVM very practical for managing storage and do not trust bitlocker, nor trust Windows to access my other partitions.

Footprint: 4GB in Storage, about 1GB in RAM 

Guide assumes you use Debian with LVM on luks2 and have virt-manager installed (not scope of this guide, there should be enough resources about this), should also work on Ubuntu

Setup Windows 11 in virt-manager with virtio network/disk on LVM2, again not scope of this guide, as enough resources exist about this topic.

Replace skoll with the Hostname of your Windows VM.

## debootstrap Debian-Hypervisor VM for Windows
Create LV and mount
```
sudo lvcreate vg00 -n skoll-hypervisor -L4G
sudo mkfs.ext4 /dev/vg00/skoll-hypervisor
sudo mkdir -p /mnt/skoll-hypervisor
sudo mount /dev/vg00/skoll-hypervisor /mnt/skoll-hypervisor/
```
Debootstrap minimal Debian
```
sudo debootstrap  --variant=minbase sid /mnt/skoll-hypervisor/
```
Enter and setup Chroot
```
sudo chroot /mnt/skoll-hypervisor

```
