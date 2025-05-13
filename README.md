# win11-on-lvm
Windows 11 on LVM (hack))
Boot Windows 11 from LVM on luks2 inside libvirt with GPU/USB-Passthrough.

Why? I find LVM very practical for managing storage and do not trust bitlocker, nor trust Windows to access my other partitions.

Footprint: 4GB in Storage, about 1GB in RAM 

Guide assumes you use Debian with LVM on luks2 and have virt-manager installed (not scope of this guide, there should be enough resources about this), should also work on Ubuntu

Setup Windows 11 in virt-manager with virtio network/disk on LVM2, again not scope of this guide as enough resources exist about this topic. Do not yet enable GPU-Passthrough.

Make sure VTd and IOMMMU is enabled in UEFI

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
apt install iproute2 ifupdown linux-image-amd64 lvm2 cryptsetup cryptsetup-initramfs e2fsprogs init libvirt-daemon libvirt-clients vi pciutils usbutils bridge-utils
```
Setup Network

copy /etc/resolv.conf from host
```
echo "domain lan
search lan
nameserver 192.168.1.1" > /etc/resolv.conf
```
Setup hostname
```
echo "skoll" > /etc/hostname
```
Add network configuration with bridge br0, change eno1 if neccessary
```
echo "source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback

iface eno1 inet manual

auto br0
iface br0 inet dhcp
  bridge_ports eno1" > /etc/network/interfaces
```
Setup fstab, I do not recommend to add /boot,  as this is managed by your main Linux
```
echo "/dev/mapper/vg00-skoll--hypervisor /               ext4   defaults 0       0" > /etc/fstab
```

Copy /etc/crypttab from Host
```
echo "sda3_crypt UUID=fef0dc81-3a98-40cf-9218-f41fd4327a6d none luks,discard" > /etc/crypttab
```
Also check if keyboard layout in /etc/default/keyboard is correctly set, run `dpkg-reconfigure keyboard-configuration` if in doubt.

update initramfs, will throw some errors, will be resolved later on.
```
update-initramfs -k all -u
```

## Setup custom Grub entry on Host
Exit chroot and setup a subdirectory on your boot-Partition and copy kernel and initramfs
```
sudo mkdir -p /boot/skoll-hypervisor
sudo cp ${chroot}/skoll-hypervisor/vmlinuz /boot/skoll-hypervisor/vmlinuz-skoll-hypervisor
sudo cp ${chroot}/}skoll-hypervisor/initrd.img /boot/skoll-hypervisor/initrd-skoll-hypervisor.img
```
Review /boot/grub/grub.cfg and use first menuentry as a base, replace the correct paths in the lines starting with linux and initrd and title, change uuid starting with gnulinux-simple- (use uuidgen), leave everything else as is and append to `/etc/grub.d/40_custom`, for me it looks like this:
```
echo "menuentry 'Windows 11 hypervisor' --class debian --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-1fb7af99-af53-4dcb-b898-57b42a80f0ef' {
        load_video
        insmod gzio
        insmod part_gpt
        insmod ext2
        set root='hd0,gpt2'
        if [ x$feature_platform_search_hint = xy ]; then
          search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gpt2 --hint-efi=hd0,gpt2 --hint-baremetal=ahci0,gpt2  6ea94cd0-e625-4a4f-a60d-c6fbd5ccc730
        else
          search --no-floppy --fs-uuid --set=root 6ea94cd0-e625-4a4f-a60d-c6fbd5ccc730
        fi
        echo    'Loading Windows 11 hypervisor ...'
        linux   /skoll-hypervisor/vmlinuz-skoll-hypervisor root=/dev/mapper/vg00-skoll--hypervisor ro
        echo    'Loading initial ramdisk ...'
        initrd  /skoll-hypervisor/initrd-skoll-hypervisor.img
}"> /etc/grub.d/40_custom
```
Update grub configuration
```
update-grub
```
Restart and boot into the new entry, you will notice, you get dropped into emergency shell (initramfs) after some minutes, the reason  is update-initramfs could not properly setup luks in the chroot, so this time you need to unlock the volume manually and update the initramfs from the running system, change command if necassary
```
cryptsetup open /dev/sda3 sda3_crypt
```
When volume is unlocke press Ctrl-D, the setu system should now continue to boot properly.
Update initramfs and copy and updat it on your boot partition
```
update-initramfs -k all -u
mount /dev/sda2 /mnt #Mount boot
cp /initrd.img /boot/skoll-hypervisor/initrd-skoll-hypervisor.img
```
Reboot to test if luks unlock works now when booting the hypervisor, your LVMs should all be available now

## Setup Virtual Machine

Back on your main system:

Assuming the Windows running in virt-manager is setup, now is time to configure it, add your GPU-Devices (like GPU and GPU Audio) in virt-manager, but do not start the VM. Add the resources that makes sense, I gave the machine all CPU-Cores and all system memory, minus 2 G (should be able to tweak this further but this is a safe  value). Do not add USB-Devices yet, as they might have different enumerators in the hypervisor system, we will get to this later.

Dump the xml-File with virsh and copy it into the hypervisor 
```
virsh dumpxml skoll > skoll.xml
```
Edit if neccessary, interface should be set to bridge / br0.
```
<interface type='bridge'>
      <mac address='52:54:00:03:da:17'/>
      <source bridge='br0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
</interface>
```
Also setup cpu topology correctly, otherwise Windows can't use all cores
```
virsh capabilities | grep topology
```
and copy the first line e.g. `<topology sockets='1' cores='4' threads='1'/>` into the `<cpu></cpu>`-Tag which then looks like this for me:
```
<cpu mode='host-passthrough' check='none' migratable='on'>
        <topology sockets='1' dies='1' clusters='1' cores='4' threads='2'/>
</cpu>
```
Next Reboot into the Hypervisor again and add the Windows-VM with
```
virsh define skoll.xml
```
Add a systemd-Unit for starting the VM and attaching the USB-Devices:
```
echo "[Unit]
Description=start domain skoll

[Service]
ExecStart=/bin/bash /opt/start-skoll/start-skoll.sh skoll
WorkingDirectory=/opt/start-skoll

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/start-skoll.service
systemctl daemon-reload
systemctl enable start-skoll
```
copy start-skoll from this repository to /opt
Replace the xml-Configs with your own devices (use lsusb to find out Vendor/Product-Ids), and update start-skoll.sh with the name of your devices (referencing the xml-Files).
e.g. you have a keyboard.xml let this be reflected as keybaord in the devices arry.

Now start the Windows-VM:
```
systemctl start start-skoll
```
If everything went well, the Windows-VM should now take over and voila you Windows on encrypted LVM :)

