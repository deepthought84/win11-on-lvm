#!/bin/bash
vm=$1

devices=("headset" "bluetooth" "mouse" "keyboard" "audio" "webcam")


function attach_usb () {
	for token in $2; do
		virsh attach-device $1 ${token}.xml
	done
}
virsh start $vm

attach_list="${devices[@]}"
attach_usb "$vm" "$attach_list"
