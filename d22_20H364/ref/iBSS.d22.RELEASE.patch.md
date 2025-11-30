# iBSS Patch for iPhone X iOS 16.7.12

## Firmware Information
- File: `iBSS.d22.RELEASE.im4p`
- Type: `ibss`
- Version: `iBoot-8422.142.2.700.1`
- Payload Size: 1,110,496 bytes

## How to Create the Patch

### Step 1: Decrypt iBSS
```bash
# Put iPhone X in DFU mode
./gaster pwn
./gaster decrypt iBSS.d22.RELEASE.im4p iBSS.d22.RELEASE.dec
```

### Step 2: Analyze Decrypted Binary
Load `iBSS.d22.RELEASE.dec` into Ghidra or IDA Pro and find:

1. **Signature Verification Function**
   - Search for string references to "IMG4" or "signature"
   - Find the function that returns signature validation result
   - Patch to always return 0 (success)

2. **Boot-args Restrictions**
   - Find references to "boot-args"
   - Patch checks that restrict boot-args values

### Step 3: Required Patches
| Description | What to Find | What to Patch |
|-------------|--------------|---------------|
| Signature bypass | CBZ/CBNZ after sig check | NOP or unconditional branch |
| Boot-args allow | Comparison for allowed args | Return 0 |

### Step 4: Create BSDIFF Patch
```bash
# After patching the binary
bsdiff iBSS.d22.RELEASE.dec iBSS.d22.RELEASE.patched iBSS.d22.RELEASE.patch
```

### Step 5: Move Patch to jboot Folder
```bash
cp iBSS.d22.RELEASE.patch ../jboot/iBSS.patch
```

## Usage
```bash
bspatch iBSS.d22.RELEASE.dec pwniBSS.dec d22_20H364/jboot/iBSS.patch
./img4 -i pwniBSS.dec -o iBSS.img4 -M apticket.der -A -T ibss
```

## Notes
- The actual patch file (BSDIFF40 format) needs to be created from the decrypted binary
- This requires a macOS system with gaster installed
- iPhone X must be connected in DFU mode for decryption
