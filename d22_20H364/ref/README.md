# ayakurume - iPhone X (iPhone10,6/D22AP) iOS 16.7.12

## Device Information
| Property | Value |
|----------|-------|
| Device | iPhone X |
| Model Identifier | iPhone10,6 |
| Board Config | D22AP |
| Chip | Apple A11 Bionic |
| iOS Version | 16.7.12 |
| Build Number | 20H364 |
| iBoot Version | iBoot-8422.142.2.700.1 |
| Kernelcache | KernelCacheBuilder_release-2429.140.2 |

## Firmware Files
From IPSW `iPhone10,3,iPhone10,6_16.7.12_20H364_Restore.ipsw`:
- `Firmware/dfu/iBSS.d22.RELEASE.im4p`
- `Firmware/dfu/iBEC.d22.RELEASE.im4p`
- `Firmware/all_flash/iBoot.d22.RELEASE.im4p`
- `kernelcache.release.iphone10b`

## Prerequisites
- macOS computer
- [gaster](https://github.com/0x7ff/gaster) - for checkm8 exploit and firmware decryption
- [img4](https://github.com/xerub/img4lib) - for IMG4 manipulation
- [SSHRD_Script](https://github.com/verygenericname/SSHRD_Script)
- [libirecovery](https://github.com/libimobiledevice/libirecovery)
- bsdiff/bspatch

## Step 1: Decrypt Firmware Files

### Using gaster (recommended for checkm8 devices)
```bash
# Put device in DFU mode and exploit
./gaster pwn

# Decrypt iBSS
./gaster decrypt iBSS.d22.RELEASE.im4p iBSS.d22.RELEASE.dec

# Decrypt iBoot
./gaster decrypt iBoot.d22.RELEASE.im4p iBoot.d22.RELEASE.dec

# Decrypt iBEC (optional, for alternative boot method)
./gaster decrypt iBEC.d22.RELEASE.im4p iBEC.d22.RELEASE.dec
```

### Extract Kernelcache
```bash
# Decompress kernelcache using img4
./img4 -i kernelcache.release.iphone10b -o kernelcache.dec
```

## Step 2: Create Patches

After decryption, patches need to be created by analyzing the binaries:

### iBSS/iBoot Patches
1. Load decrypted binary into Ghidra/IDA Pro
2. Find signature verification functions
3. Patch to bypass checks
4. Create BSDIFF patch:
```bash
bsdiff iBSS.d22.RELEASE.dec iBSS.d22.RELEASE.patched iBSS.d22.RELEASE.patch
bsdiff iBoot.d22.RELEASE.dec iBoot.d22.RELEASE.patched iBoot.d22.RELEASE.patch
```

### Kernelcache Patches
1. Analyze decompressed kernelcache
2. Find and patch:
   - AMFI (AppleMobileFileIntegrity) bypass
   - Sandbox bypass
   - Root filesystem mount restrictions
   - Code signing enforcement
3. Create bytepatch file (see `kc.bpatch`)

## Step 3: Apply Patches and Create Boot Images

```bash
# Apply patches to decrypted files
bspatch iBSS.d22.RELEASE.dec pwniBSS.dec iBSS.d22.RELEASE.patch
bspatch iBoot.d22.RELEASE.dec pwniBoot.dec iBoot.d22.RELEASE.patch

# Create signed IMG4 files
./img4 -i pwniBSS.dec -o iBSS.img4 -M apticket.der -A -T ibss
./img4 -i pwniBoot.dec -o iBoot.img4 -M apticket.der -A -T ibec

# Apply kernelcache patches
./img4 -i kernelcache.dec -o kernelcachd -P kc.bpatch -M apticket.der
```

## Alternative Method: Patched Kernelcache in Preboot

You can also place a patched kernelcache inside preboot and boot by sending iBSS/iBoot.

### Additional Steps via SSHRD
```bash
# On macOS
./img4 -i kernelcache.release.iphone10b -o kernelcachd -P kc.bpatch -M apticket.der
scp -P {port} kernelcachd root@localhost:/mnt6/{UUID}/System/Library/Caches/com.apple.kernelcaches/kernelcachd
```

### First-run preparations
```bash
# On macOS
./gaster pwn
./gaster decrypt iBSS.d22.RELEASE.im4p iBSS.d22.RELEASE.dec
./gaster decrypt iBoot.d22.RELEASE.im4p iBoot.d22.RELEASE.dec
bspatch iBSS.d22.RELEASE.dec pwniBSS.dec iBSS.d22.RELEASE.patch
bspatch iBoot.d22.RELEASE.dec pwniBoot.dec iBoot.d22.RELEASE.patch
./img4 -i pwniBSS.dec -o iBSS.img4 -M apticket.der -A -T ibss
./img4 -i pwniBoot.dec -o iBoot.img4 -M apticket.der -A -T ibec
```

*iBoot's boot-args is set to `rd=disk0s1s8 serial=3`. (`rd=disk0s1s8` is required, others can be modified as needed)

### First Run
```bash
# On macOS
./gaster pwn
irecovery -f iBSS.img4
irecovery -f iBoot.img4
```

After confirming dropbear startup:
```bash
# On macOS
iproxy {port} 44
ssh root@localhost -p {port}
scp -P {port} bootstrap-ssh.tar root@localhost:/var/root
scp -P {port} org.swift.libswift_5.0-electra2_iphoneos-arm.deb root@localhost:/var/root
scp -P {port} com.ex.substitute_2.3.1_iphoneos-arm.deb root@localhost:/var/root
scp -P {port} com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb root@localhost:/var/root
```

```bash
# On iOS
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

### Running (subsequent boots)
```bash
# On macOS
./gaster pwn
irecovery -f iBSS.img4
irecovery -f iBoot.img4
```

## Required Patches Status

| Patch File | Status |
|------------|--------|
| iBSS.d22.RELEASE.patch | TODO - Requires reverse engineering |
| iBoot.d22.RELEASE.patch | TODO - Requires reverse engineering |
| kc.bpatch | Template created - Requires offsets |

## Notes
- Storage requirement: 32 GB or more (5GB will be used for rootfs duplication)
- This uses the checkm8 bootrom exploit which is unpatchable on A11 devices
- Verbose boot may not work; use serial debugging for troubleshooting
