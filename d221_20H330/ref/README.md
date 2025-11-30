# ayakurume - iPhone X (iPhone10,6/D221AP) iOS 16.7.11

# Alternative Method
You can also place a patched kernelcache inside preboot and boot by sending iBSS/iBoot.

## [Additional Steps] Setting up the necessary components via sshrd
- macos side
```
./img4 -i kernelcache.release.d221 -o kernelcachd -P kc.bpatch -M apticket.der
scp -P {port} kernelcachd root@localhost:/mnt6/{UUID}/System/Library/Caches/com.apple.kernelcaches/kernelcachd
```

## First-run preparations
- macos side
```
./gaster pwn
./gaster decrypt iBSS.d221.RELEASE.im4p iBSS.d221.RELEASE.dec
./gaster decrypt iBoot.d221.RELEASE.im4p iBoot.d221.RELEASE.dec
bspatch iBSS.d221.RELEASE.dec pwniBSS.dec iBSS.d221.RELEASE.patch
bspatch iBoot.d221.RELEASE.dec pwniBoot.dec iBoot.d221.RELEASE.patch
./img4 -i pwniBSS.dec -o iBSS.img4 -M apticket.der -A -T ibss
./img4 -i pwniBoot.dec -o iBoot.img4 -M apticket.der -A -T ibec
```
*iBoot's boot-args is set to `rd=disk0s1s8 serial=3`. (`rd=disk0s1s8` is required, others can be modified as needed)

## First run
- macos side
```
./gaster pwn
irecovery -f iBSS.img4
irecovery -f iBoot.img4
```

After confirming the startup of dropbear
- macos side
```
iproxy {port} 44
```
```
ssh root@localhost -p {port}
scp -P {port} bootstrap-ssh.tar root@localhost:/var/root
scp -P {port} org.swift.libswift_5.0-electra2_iphoneos-arm.deb root@localhost:/var/root
scp -P {port} com.ex.substitute_2.3.1_iphoneos-arm.deb root@localhost:/var/root
scp -P {port} com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb root@localhost:/var/root
```

- ios side
```
mount -uw /
cd /var/root
tar --preserve-permissions --no-overwrite-dir -xvf bootstrap-ssh.tar -C /
/prep_bootstrap.sh
apt update
apt upgrade -y
apt install org.coolstar.sileo
dpkg -i *.deb
rm *.deb
rm bootstrap-ssh.tar
touch /.installed_ayakurume
reboot
```

## Running
- macos side
```
./gaster pwn
irecovery -f iBSS.img4
irecovery -f iBoot.img4
```

## Notes
- Device: iPhone X (iPhone10,6/D221AP)
- iOS Version: 16.7.11
- Build Number: 20H330
- Chip: Apple A11 Bionic (checkm8 compatible)
- Storage requirement: 32 GB or more (5GB will be used for rootfs duplication)

## Required Patches (TODO)
- [ ] iBSS.d221.RELEASE.patch
- [ ] iBoot.d221.RELEASE.patch
- [ ] kc.bpatch (kernelcache bytepatch for iOS 16.7.11)
