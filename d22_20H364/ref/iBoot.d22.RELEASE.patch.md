# iBoot Patch for iPhone X iOS 16.7.12

## Firmware Information
- File: `iBoot.d22.RELEASE.im4p`
- Type: `ibot`
- Version: `iBoot-8422.142.2.700.1`
- Payload Size: 1,110,496 bytes

## How to Create the Patch

### Step 1: Decrypt iBoot
```bash
# Put iPhone X in DFU mode
./gaster pwn
./gaster decrypt iBoot.d22.RELEASE.im4p iBoot.d22.RELEASE.dec
```

### Step 2: Analyze Decrypted Binary
Load `iBoot.d22.RELEASE.dec` into Ghidra or IDA Pro and find:

1. **Signature Verification**
   - IMG4 signature validation
   - Hash verification functions

2. **Boot-args Handling**
   - Find `boot-args` string reference
   - Locate setenv/getenv for boot-args
   - Set default boot-args: `rd=disk0s1s8 serial=3`

3. **Security Checks**
   - Production/development mode checks
   - Debug enable flags

### Step 3: Required Patches
| Description | What to Find | What to Patch |
|-------------|--------------|---------------|
| IMG4 signature bypass | Signature verification return | MOV X0, #0; RET |
| Boot-args set | boot-args string handler | Set `rd=disk0s1s8 serial=3` |
| Debug enable | Debug flag check | Always return enabled |
| Production bypass | Production/dev check | Always return dev mode |

### Step 4: Boot-args Configuration
The patched iBoot should set:
```
boot-args=rd=disk0s1s8 serial=3
```

Where:
- `rd=disk0s1s8` - Root device (fakefs volume) **REQUIRED**
- `serial=3` - Enable serial debugging **OPTIONAL**

Other useful boot-args:
- `debug=0x2014e` - Enable verbose boot + debugging
- `cs_enforcement_disable=1` - Disable code signing (kernel level)
- `amfi_get_out_of_my_way=1` - Disable AMFI (kernel level)

### Step 5: Create BSDIFF Patch
```bash
# After patching the binary
bsdiff iBoot.d22.RELEASE.dec iBoot.d22.RELEASE.patched iBoot.d22.RELEASE.patch
```

### Step 6: Move Patch to ref Folder
```bash
cp iBoot.d22.RELEASE.patch ../ref/
```

## Usage
```bash
bspatch iBoot.d22.RELEASE.dec pwniBoot.dec d22_20H364/ref/iBoot.d22.RELEASE.patch
./img4 -i pwniBoot.dec -o iBoot.img4 -M apticket.der -A -T ibec
```

## Boot Sequence
1. `./gaster pwn` - Exploit bootrom
2. `irecovery -f iBSS.img4` - Send patched iBSS
3. `irecovery -f iBoot.img4` - Send patched iBoot
4. Device boots with patched kernel and jailbreak environment

## Notes
- The actual patch file (BSDIFF40 format) needs to be created from the decrypted binary
- This requires a macOS system with gaster installed
- iPhone X must be connected in DFU mode for decryption
- The patched iBoot is sent as iBEC (second stage bootloader)
