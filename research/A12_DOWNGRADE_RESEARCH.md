# A12+ iOS Downgrade Research (ไม่ต้องใช้ Private Key)

## สารบัญ
1. [ภาพรวมปัญหา](#ภาพรวมปัญหา)
2. [สถาปัตยกรรม Boot Chain ของ Apple](#สถาปัตยกรรม-boot-chain-ของ-apple)
3. [Nonce Entanglement บน A12+](#nonce-entanglement-บน-a12)
4. [SEPROM และ Signature Verification](#seprom-และ-signature-verification)
5. [ทฤษฎีการโจมตีที่เป็นไปได้](#ทฤษฎีการโจมตีที่เป็นไปได้)
6. [สรุปและข้อจำกัด](#สรุปและข้อจำกัด)

---

## ภาพรวมปัญหา

การดาวน์เกรด iOS บน A12+ (iPhone XS, XR และใหม่กว่า) ไปยังเวอร์ชันที่ไม่ได้ลงชื่อ (unsigned) โดยไม่มี private key ของ Apple เป็นสิ่งที่ **ยากมากจนเกือบเป็นไปไม่ได้** ด้วยเหตุผลหลายประการ:

### ปัญหาหลัก 3 ประการ:

1. **ไม่มี BootROM Exploit สำหรับ A12+**
   - checkm8 (CVE-2019-8900) ใช้งานได้เฉพาะ A5-A11
   - A12+ มี Use-After-Free vulnerability เหมือนกัน แต่ memory leak ที่จำเป็นถูก patch แล้ว

2. **Nonce Entanglement**
   - ApNonce ถูกเข้ารหัสด้วย UID Key ของอุปกรณ์
   - ทำให้ Generator เดียวกันสร้าง ApNonce ที่ต่างกันบนแต่ละอุปกรณ์

3. **SEPROM Signature Verification**
   - SEP ตรวจสอบ signature แยกต่างหากจาก AP
   - ไม่มี SEPROM exploit สำหรับ A12+

---

## สถาปัตยกรรม Boot Chain ของ Apple

### Boot Chain ปกติ:
```
SecureROM → LLB → iBoot → Kernel → iOS
     ↓          ↓        ↓
  [Verify]  [Verify]  [Verify]
```

### IMG4 Format และ Signature Verification:

```
┌─────────────────────────────────────────────────────────────┐
│                      IMG4 Container                          │
├─────────────────────────────────────────────────────────────┤
│  IM4P (Payload)                                              │
│  ├── Type: iBSS, iBEC, Kernel, etc.                         │
│  ├── Version                                                 │
│  └── Encrypted/Compressed Data                               │
├─────────────────────────────────────────────────────────────┤
│  IM4M (Manifest)                                             │
│  ├── MANB: Manifest Body                                     │
│  │   ├── MANP: Manifest Properties                           │
│  │   │   ├── BNCH: Boot Nonce Hash (ApNonce)                │
│  │   │   ├── ECID: Exclusive Chip ID                        │
│  │   │   └── snon: SEP Nonce                                │
│  │   └── Component Digests (SHA-384 hashes)                  │
│  └── Signature (RSA-4096 or ECDSA)                          │
└─────────────────────────────────────────────────────────────┘
```

### Signature Verification Process:

```c
// SecureROM/iBoot Signature Check (Simplified)
int verify_img4_signature(img4_t *img4) {
    // 1. Extract manifest (IM4M)
    im4m_t *manifest = img4_get_manifest(img4);

    // 2. Verify certificate chain to Apple Root CA (embedded in ROM)
    if (!verify_chain_to_root_ca(manifest->cert_chain, ROM_ROOT_CA)) {
        return VERIFY_FAILED;
    }

    // 3. Verify signature using RSA-4096/ECDSA with SHA-384
    if (!verify_signature(manifest->body, manifest->signature, manifest->cert_chain)) {
        return VERIFY_FAILED;
    }

    // 4. Check ECID matches device
    if (manifest->ecid != get_device_ecid()) {
        return VERIFY_FAILED;
    }

    // 5. Check ApNonce matches device-generated nonce
    if (memcmp(manifest->bnch, device_boot_nonce, 32) != 0) {
        return VERIFY_FAILED;
    }

    // 6. Verify payload hash matches manifest
    if (!verify_payload_hash(img4->payload, manifest->digest)) {
        return VERIFY_FAILED;
    }

    return VERIFY_SUCCESS;
}
```

### Root CA Public Key ใน ROM:
- Apple Root CA public key ถูก burn ลงใน ROM (read-only)
- ใช้ RSA-4096 หรือ ECDSA สำหรับ signature verification
- **ไม่สามารถเปลี่ยนแปลงได้** โดยไม่มี private key

---

## Nonce Entanglement บน A12+

### วิธีการทำงานของ ApNonce บน A11 และต่ำกว่า:

```
Generator (0x1111111111111111)
          ↓
    [Reverse Bytes]
          ↓
    [SHA-384 Hash]
          ↓
   ApNonce (32 bytes)
```

**ปัญหา**: Generator เดียวกันสร้าง ApNonce เดียวกันบนทุกอุปกรณ์

### วิธีการทำงานของ ApNonce บน A12+:

```
Generator (0x1111111111111111)
          ↓
    [AES-128 Encrypt with UID Key 0x8A3]  ← เฉพาะอุปกรณ์!
          ↓
    Entangled Generator
          ↓
    [SHA-384 Hash]
          ↓
   ApNonce (32 bytes) ← ไม่เหมือนใครในโลก!
```

### กระบวนการ Entanglement แบบละเอียด:

```c
// A12+ ApNonce Generation (Conceptual)
uint8_t generate_apnonce_a12(uint64_t generator) {
    // 1. Static constant
    uint8_t constant[16] = {0x56, 0x82, 0x41, 0x65, 0x65, 0x51, 0xe0, 0xcd,
                            0xf5, 0x6f, 0xf8, 0x4c, 0xc1, 0x1a, 0x79, 0xef};

    // 2. Derive AES Key 0x8A3 using UID Key (device-specific, hardware fused)
    uint8_t aes_key_8a3[16];
    aes_encrypt(constant, uid_key, aes_key_8a3);  // UID Key is in hardware!

    // 3. Entangle generator
    uint8_t generator_bytes[16] = {0};
    memcpy(generator_bytes, &generator, 8);

    uint8_t entangled[16];
    aes_encrypt(generator_bytes, aes_key_8a3, entangled);

    // 4. Hash to get ApNonce
    uint8_t apnonce[48];
    sha384(entangled, 16, apnonce);

    return apnonce;  // First 32 bytes
}
```

### ปัญหาสำคัญ:
- **UID Key** ถูก fuse ไว้ในฮาร์ดแวร์ระหว่างการผลิต
- ไม่มีทางอ่าน UID Key ออกมาได้ (ถูกออกแบบมาเพื่อป้องกัน extraction)
- AES Engine ถูกออกแบบมาให้ใช้ UID Key เป็น key ได้ แต่ไม่สามารถ export ออกมา
- มี Side-channel protections (DPA, SPA countermeasures)

---

## SEPROM และ Signature Verification

### SEP (Secure Enclave Processor):

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Processor                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │  SecureROM  │ →  │     LLB     │ →  │    iBoot    │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         ↑                                     │              │
│         │                                     │ Load SEP     │
│         │                                     ↓              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    TZ0 Memory Region                  │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │            Secure Enclave Processor              │ │   │
│  │  │  ┌─────────────┐                                │ │   │
│  │  │  │   SEPROM    │ ← Immutable, has own Root CA   │ │   │
│  │  │  └─────────────┘                                │ │   │
│  │  │         ↓                                        │ │   │
│  │  │  ┌─────────────┐                                │ │   │
│  │  │  │    SEPOS    │ ← Verified by SEPROM           │ │   │
│  │  │  └─────────────┘                                │ │   │
│  │  │         ↓                                        │ │   │
│  │  │  ┌─────────────┐                                │ │   │
│  │  │  │   SEP Apps  │ ← TouchID, FaceID, Keychain    │ │   │
│  │  │  └─────────────┘                                │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### SEPROM Boot Process:

1. **AP iBoot loads SEP firmware** (`sep-firmware.img4`) into TZ0 memory
2. **AP signals SEP** via hardware mailbox
3. **SEPROM parses IMG4** container
4. **SEPROM verifies signature** against SEP-specific Root CA (embedded in SEPROM)
5. **Boot Monitor hardware** resets SEP core
6. **SCIP (Secure Code Isolation Policy)** permits execution of verified memory region

### Known SEPROM Exploits:

| Exploit | Affected Chips | Requirements |
|---------|----------------|--------------|
| blackbird | A8, A9, A10, T2 | Requires checkm8 first |
| TZ0 bypass | A8, A9, A10 | Requires checkm8 first |

**A12+**: ไม่มี SEPROM exploit เนื่องจาก:
- ไม่มี BootROM exploit เพื่อเริ่มต้น attack chain
- ไม่สามารถตรวจสอบได้ว่า vulnerability ยังมีอยู่หรือไม่

### TZ0 Attack (A8-A10 only):

```c
// TZ0 Attack Concept (NOT applicable to A12+)
// This works on A8-A10 with checkm8

// 1. Use checkm8 to gain SecureROM code execution
checkm8_exploit();

// 2. Modify IO mapping register to bypass TZ0 protection
// TZ0 register controls SEP memory isolation
write_io_register(TZ0_BYPASS_VALUE);

// 3. Race condition with AP to modify SEPOS before verification
// This allows loading unsigned SEPOS
```

---

## ทฤษฎีการโจมตีที่เป็นไปได้

### 1. หา BootROM Exploit ใหม่สำหรับ A12+ (ยากมาก)

```
สถานะ: A12 มี Use-After-Free แต่ Memory Leak ถูก patch

ปัญหา:
├── Memory leak ที่ใช้ใน checkm8 ถูกทำให้ unreachable
├── Apple ทราบเรื่อง Use-After-Free แล้ว
├── ต้องหา memory leak ใหม่ หรือ primitive อื่น
└── SecureROM เป็น read-only, ถ้ามี bug ก็ unpatchable

ความเป็นไปได้: ต่ำมาก (ต้องหา 0-day ใหม่)
```

### 2. ApNonce Collision Attack (เป็นไปไม่ได้ในทางปฏิบัติ)

```
ทฤษฎี: หา Generator ที่สร้าง ApNonce ตรงกับที่บันทึกไว้

ปัญหา:
├── SHA-384 มี 384-bit output
├── ApNonce ใช้ 256 bits แรก
├── Collision resistance: 2^128 operations minimum
├── A12+ เพิ่ม AES encryption ก่อน hash
└── ต้องรู้ UID Key เพื่อคำนวณ → เป็นไปไม่ได้

เวลาที่ต้องใช้: นานกว่าอายุจักรวาล
```

### 3. UID Key Extraction (เป็นไปไม่ได้ในปัจจุบัน)

```
UID Key Protection:
├── Fused ใน silicon ระหว่างการผลิต
├── ใช้ได้เฉพาะผ่าน AES Engine
├── Software ไม่สามารถอ่านค่าได้
├── มี SPA (Static Power Analysis) protection
├── มี DPA (Dynamic Power Analysis) countermeasures
└── Apple ไม่เก็บ UID Key (สร้างในอุปกรณ์)

Side-Channel Attack:
├── ต้องมี physical access
├── ต้องมี equipment ราคาแพงมาก
├── ต้องรู้ตำแหน่งที่แน่นอนใน silicon
├── Apple เพิ่ม protections ใน A12+
└── ยังไม่มีใครสาธิตได้สำเร็จในที่สาธารณะ
```

### 4. Forge SHSH Blob Signature (เป็นไปไม่ได้)

```
RSA-4096 Security:
├── Key length: 4096 bits
├── Best known attack: General Number Field Sieve
├── Estimated time to break: ~10^30 years
└── Even with all computing power on Earth

ECDSA Alternative:
├── Apple ใช้ P-256 curve
├── Discrete logarithm problem
└── เช่นเดียวกัน, เป็นไปไม่ได้ในทางปฏิบัติ

สรุป: ต้องมี Private Key ของ Apple
```

### 5. TSS Server Compromise (ผิดกฎหมายและยากมาก)

```
ทฤษฎี: Compromise Apple's TATSU server (gs.apple.com)

ปัญหา:
├── ผิดกฎหมาย (Computer Fraud and Abuse Act, etc.)
├── Apple มี security team ระดับโลก
├── Infrastructure น่าจะมี HSM (Hardware Security Modules)
├── Private keys น่าจะถูกเก็บใน HSM
└── ไม่ใช่ทางที่ถูกต้องตามกฎหมาย

ความเป็นไปได้: ไม่ควรพิจารณา
```

### 6. Quantum Computing (อนาคตไกลมาก)

```
Shor's Algorithm:
├── สามารถ break RSA และ ECDSA ได้ในทางทฤษฎี
├── ต้องการ Quantum Computer ขนาดใหญ่มาก
├── ปัจจุบันยังทำไม่ได้
└── Apple อาจเปลี่ยนเป็น post-quantum crypto ก่อน

Timeline: อาจจะ 10-20+ ปี (ถ้าเป็นไปได้)
```

---

## สรุปและข้อจำกัด

### สถานะปัจจุบัน (2024-2025):

| Attack Vector | Feasibility | Notes |
|---------------|-------------|-------|
| New BootROM Exploit | ต่ำมาก | ต้องหา 0-day ใหม่ |
| ApNonce Collision | เป็นไปไม่ได้ | SHA-384 + AES too strong |
| UID Key Extraction | เป็นไปไม่ได้ (ปัจจุบัน) | Hardware protection |
| Signature Forge | เป็นไปไม่ได้ | RSA-4096 unbreakable |
| SEPROM Exploit | ไม่มี | No A12+ SEPROM bugs public |
| Nonce Entanglement Bypass | เป็นไปไม่ได้ | Needs UID Key |

### สิ่งที่ยังทำได้ (ถูกกฎหมาย):

1. **บันทึก SHSH Blobs ตอนที่ iOS version ยัง signed**
   - ต้องใช้ jailbreak เพื่อดึง ApNonce/Generator pair
   - ใช้เครื่องมือเช่น blobsaver หรือ TSS Saver

2. **Delay OTA Updates**
   - ใช้ supervision profile เพื่อ block updates

3. **Research**
   - ศึกษา SecureROM dump ของ A12+ (ถ้ามี)
   - วิเคราะห์ possible memory corruption bugs

### ข้อจำกัดสำคัญสำหรับโปรเจค ayakurume:

```
ayakurume ใช้งานได้กับ: A8-A11 (checkm8 vulnerable)
├── iPhone 6s (A9) ✓
├── iPhone X (A11) ✓
└── iPhone XS+ (A12+) ✗ ไม่รองรับ

เหตุผล:
├── checkm8 ไม่ทำงานบน A12+
├── ไม่สามารถ send patched iBSS/iBoot ได้
└── ไม่มีทางเข้าถึง boot chain
```

---

## References

- [checkm8 Exploit - The Apple Wiki](https://theapplewiki.com/wiki/Checkm8_Exploit)
- [Nonce - The Apple Wiki](https://theapplewiki.com/wiki/Nonce)
- [Demystifying the Secure Enclave Processor - Black Hat 2016](https://blackhat.com/docs/us-16/materials/us-16-Mandt-Demystifying-The-Secure-Enclave-Processor.pdf)
- [Pangu Team SEP Attack Research](https://www.securitynewspaper.com/2020/07/27/team-pangu-shows-an-unpatchable-sep-flaw-apple-ios-14-security-in-big-trouble/)
- [Apple Platform Security Guide](https://help.apple.com/pdf/security/en_US/apple-platform-security-guide.pdf)
- [futurerestore - GitHub](https://github.com/futurerestore/futurerestore)
- [iOS Update Replay Attacks - ApNonce](https://omarsiman.com/posts/apnonce/)
- [A Comprehensive Write-up of the checkm8 BootROM Exploit](https://alfiecg.uk/2023/07/21/A-comprehensive-write-up-of-the-checkm8-BootROM-exploit.html)

---

## สรุปสั้นๆ

**คำตอบสำหรับคำถาม: สามารถดาวน์เกรด A12+ ไปยังเวอร์ชันที่ไม่ได้ลงชื่อโดยไม่มี private key ได้ไหม?**

**คำตอบ: ไม่ได้ในทางปฏิบัติ**

เหตุผล:
1. ไม่มี BootROM exploit สำหรับ A12+
2. Nonce entanglement ต้องการ UID Key ซึ่งอ่านไม่ได้
3. Signature verification ใช้ RSA-4096/ECDSA ที่ไม่สามารถ forge ได้
4. SEPROM มี chain of trust แยกต่างหาก
5. Apple Root CA public key ถูก burn ใน ROM

**ทางออกเดียว**: หา BootROM 0-day exploit ใหม่สำหรับ A12+ ซึ่งยากมากและอาจไม่มีอยู่จริง
