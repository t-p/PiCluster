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
