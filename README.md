# win11-on-lvm
Windows 11 on LVM (hack))
Boot Windows 11 from LVM on luks2 inside libvirt with GPU/USB-Passthrough.

Why? I find LVM very practical for managing storage and do not trust bitlocker, nor trust Windows to access my other partitions.

Footprint: 4GB in Storage, about 1GB in RAM 

Guide assumes you use Debian with LVM on luks2 and have virt-manager installed (not scope of this guide, there should be enough resources about this), should also work on Ubuntu

Setup Windows 11 in virt-manager with virtio network/disk on LVM2, again not scope of this guide as enough resources exist about this topic.

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
Enter and setup root Password
```
sudo chroot /mnt/skoll-hypervisor
passwd root
```
Install Software
```
apt install iproute2 ifupdown linux-image-amd64 lvm2 cryptsetup cryptsetup-initramfs e2fsprogs init libvirt-daemon vi pciutils usbutils bridge-utils
```
Setup Network

copy /resolv.conf from host
```
echo "domain lan
search lan
nameserver 192.168.1.1" > /etc/resolv.conf
```
Setup hostname
```
echo "skoll" > /etc/hostname
```
Add network configuration with bridge br0
```
echo "source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback

iface eno1 inet manual

auto br0
iface br0 inet dhcp
  bridge_ports eno1" > /etc/network/interfaces
```
Setup fstab 
```
echo "/dev/mapper/vg00-skoll-hypervisor /               ext4   defaults 0       0" > /etc/fstab
```

Copy /etc/crypttab from Host
```
echo "sda3_crypt UUID=fef0dc81-3a98-40cf-9218-f41fd4327a6d none luks,discard" > /etc/crypttab
```


