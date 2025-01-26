# PiCluster
PiCluster is a compact Kubernetes testbed built on a Turing Pi 2.5 carrier board,

![Turing Pi Board](images/turing-pi-board.jpg)

# Flash eMMC on Rasperry Pi Compute Module 4
* Download the latest Raspberry Pi OS Lite image from the [official website](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-64-bit)
* Copy to the image into `image` folder on your micro SD card
* insert the micro SD card on the back of your Turin Pi carrier board
* log into your Tourin Pi carrier board, default password is `turing`:
```bash
ssh root@turingpi.local
```
* Flash the image to the eMMC on the first Raspberry Pi Compute Module 4:
```bash
tpi flash -n 1 -l -i /mnt/sdcard/images/2024-11-19-raspios-bookworm-arm64-lite.img
```
* Mount the eMMC:
```bash
tpi advanced msd --node 1
mount /dev/sda1 /mnt/bootfs
```
* Enable uart messages to see the login logs:
```bash
echo "enable_uart=1" >> /mnt/bootfs/config.txt
```
* Enable SSH login, usename is `pi` and password is `raspberry`:
```bash
echo 'pi:$6$c70VpvPsVNCG0YR5$l5vWWLsLko9Kj65gcQ8qvMkuOoRkEagI90qi3F/Y7rm8eNYZHW8CY6BOIKwMH7a3YYzZYL90zf304cAHLFaZE0' > /mnt/bootfs/userconf
```
* Unmount the eMMC:
```bash
umount /mnt/bootfs
```
* Reboot the node:
```bash
tpi power -n 1 off
tpi power -n 1 on
```
* You can check the boot logs using the following command:
```bash
tpi uart get -n 1
```
* Repeat the same steps for the other Raspberry Pi Compute Module 4 nodes
