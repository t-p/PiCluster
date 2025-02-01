# PiCluster
PiCluster is a compact Kubernetes testbed built on a Turing Pi 2.5 carrier board,

![Turing Pi Board](images/turing-pi-board.jpg)

## Flash the eMMC on the Rasperry Pi Compute Module 4 and confidure the nodes
* Download the latest Raspberry Pi OS Lite image from the [official website](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-64-bit)
* Copy to the image into `image` folder on your micro SD card
* Insert the micro SD card on the back of your Turin Pi carrier board
* Log into your Turing Pi carrier board, default password is `turing`:
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
* Enable uart messages to see the boot logs:
```bash
echo "enable_uart=1" >> /mnt/bootfs/config.txt
```
* Enable the SSH server:
```bash
touch /mnt/bootfs/ssh
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
* Repeat the same steps for the other Compute Module nodes

* add all nodes IP addresses to the `/etc/hosts` file for each Compute Module, like:
```
127.0.0.1             localhost
192.168.88.162 node01 node01.local
192.168.88.167 node02 node02.local
192.168.88.164 node03 node03.local
192.168.88.163 node04 node04.local
```
* change the hostname of each node to match the IP address:
```bash
hostnamectl set-hostname node01
```
* enable cgroups in `/boot/firmware/cmdline.txt` by appending cgroup_memory=1 cgroup_enable=memory:
```bash
console=serial0,115200 console=tty1 root=PARTUUID=640fbb04-02 rootfstype=ext4 fsck.repair=yes rootwait cgroup_memory=1 cgroup_enable=memory
```
## Install k3s on the Turing Pi Cluster
* Kybernetes stack: https://docs.k3s.io/, https://kube-vip.io/, https://github.com/alexellis/k3sup

* initialize the master node:
```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --node-ip 192.168.88.163 --disable local-storage --data-dir /mnt/k3s-data
```
* because of the `--data-dir` option, the server token is stored in `/mnt/k3s-data/server/node-token`
```bash
cat /mnt/k3s-data/server/node-token
```
* add worker nodes to the cluster:
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.88.163:6443 K3S_TOKEN=myServerToken sh -
```
* label all worker nodes:
```bash
kubectl label nodes node01 kubernetes.io/role=worker
kubectl label nodes node02 kubernetes.io/role=worker
kubectl label nodes node04 kubernetes.io/role=worker
```
* also label the `node-type`:
```bash
kubectl label nodes node01 node-type=worker
kubectl label nodes node02 node-type=worker
kubectl label nodes node04 node-type=worker
```
