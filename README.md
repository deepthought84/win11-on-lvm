# win11-on-lvm
Windows 11 on LVM (hack))
Boot Windows 11 from LVM on luks2 inside libvirt with GPU/USB-Passthrough

Guide assumes you use Debian with LVM on luks2 and have virt-manager installed (not scope of this guide, there should be enough resources about this), should also work on Ubuntu

Setup Windows in virt-manager with virtio network/disk on 

## debootstrap Debian
Create LV
```
sudo lvcreate vg00 -n skoll-hypervisor -L4G
sudo mkfs.ext4 /dev/vg00/skoll-hypervisor
sudo mount /dev/vg00/skoll-hypervisor /mnt/skoll-hypervisor/
sudo debootstrap  --variant=minbase sid /mnt/skoll-hypervisor/
chroot /mnt/skoll-hypervisor
```
