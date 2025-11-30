#!/usr/bin/env python3
"""
IM4P Parser - Extract and analyze Apple IM4P firmware files
For use with ayakurume jailbreak project
"""

import struct
import sys
import os

def parse_asn1_length(data, offset):
    """Parse ASN.1 length field"""
    length_byte = data[offset]
    if length_byte < 0x80:
        return length_byte, offset + 1
    else:
        num_bytes = length_byte & 0x7F
        length = 0
        for i in range(num_bytes):
            length = (length << 8) | data[offset + 1 + i]
        return length, offset + 1 + num_bytes

def parse_im4p(filename):
    """Parse an IM4P file and extract its components"""
    with open(filename, 'rb') as f:
        data = f.read()

    print(f"[*] Parsing: {filename}")
    print(f"[*] File size: {len(data)} bytes")

    # Check for IM4P magic at expected location
    if data[4:8] != b'IM4P':
        # Try alternative location
        if b'IM4P' in data[:20]:
            magic_offset = data.find(b'IM4P')
            print(f"[*] Found IM4P magic at offset {magic_offset}")
        else:
            print("[!] Not a valid IM4P file")
            return None

    offset = 0

    # Parse SEQUENCE header
    if data[offset] != 0x30:
        print("[!] Expected SEQUENCE tag")
        return None

    seq_len, offset = parse_asn1_length(data, offset + 1)
    print(f"[*] SEQUENCE length: {seq_len}")

    # Parse IM4P tag (IA5STRING)
    if data[offset] != 0x16:
        print("[!] Expected IA5STRING tag for IM4P magic")
        return None

    tag_len, offset = parse_asn1_length(data, offset + 1)
    im4p_magic = data[offset:offset + tag_len].decode('ascii')
    print(f"[*] Magic: {im4p_magic}")
    offset += tag_len

    # Parse type (IA5STRING) - ibss, ibec, ibot, etc.
    if data[offset] != 0x16:
        print("[!] Expected IA5STRING tag for type")
        return None

    type_len, offset = parse_asn1_length(data, offset + 1)
    fw_type = data[offset:offset + type_len].decode('ascii')
    print(f"[*] Type: {fw_type}")
    offset += type_len

    # Parse description/version (IA5STRING)
    if data[offset] != 0x16:
        print("[!] Expected IA5STRING tag for description")
        return None

    desc_len, offset = parse_asn1_length(data, offset + 1)
    description = data[offset:offset + desc_len].decode('ascii')
    print(f"[*] Version: {description}")
    offset += desc_len

    # Parse payload (OCTET STRING)
    if data[offset] != 0x04:
        print("[!] Expected OCTET STRING tag for payload")
        return None

    payload_len, offset = parse_asn1_length(data, offset + 1)
    payload = data[offset:offset + payload_len]
    print(f"[*] Payload size: {payload_len} bytes")
    print(f"[*] Payload offset: {offset}")

    # Check if payload is encrypted (look for compression magic or encrypted data)
    payload_magic = payload[:4]
    print(f"[*] Payload magic: {payload_magic.hex()}")

    # Look for KBAG (key bag) - optional component
    kbag_offset = offset + payload_len
    kbags = []

    while kbag_offset < len(data):
        if data[kbag_offset] == 0x30:  # SEQUENCE
            # Try to parse KBAG
            try:
                kbag_len, kbag_data_offset = parse_asn1_length(data, kbag_offset + 1)

                # Check for KBAG tag
                if data[kbag_data_offset] == 0x16:  # IA5STRING
                    tag_len, inner_offset = parse_asn1_length(data, kbag_data_offset + 1)
                    tag_value = data[inner_offset:inner_offset + tag_len]

                    if tag_value == b'KBAG':
                        print(f"\n[*] Found KBAG at offset {kbag_offset}")

                        # Parse KBAG contents
                        inner_offset += tag_len
                        if data[inner_offset] == 0x04:  # OCTET STRING
                            kbag_content_len, inner_offset = parse_asn1_length(data, inner_offset + 1)
                            kbag_content = data[inner_offset:inner_offset + kbag_content_len]

                            # KBAG structure: type (4 bytes) + IV (16 bytes) + Key (32 bytes)
                            if len(kbag_content) >= 52:
                                kbag_type = struct.unpack('<I', kbag_content[:4])[0]
                                iv = kbag_content[4:20]
                                key = kbag_content[20:52]

                                print(f"    KBAG Type: {kbag_type} ({'Production' if kbag_type == 1 else 'Development'})")
                                print(f"    IV (wrapped):  {iv.hex()}")
                                print(f"    Key (wrapped): {key.hex()}")

                                kbags.append({
                                    'type': kbag_type,
                                    'iv': iv.hex(),
                                    'key': key.hex()
                                })

                        kbag_offset = inner_offset + kbag_content_len
                        continue
            except:
                pass

        kbag_offset += 1

    return {
        'magic': im4p_magic,
        'type': fw_type,
        'version': description,
        'payload_offset': offset,
        'payload_size': payload_len,
        'kbags': kbags
    }

def extract_payload(filename, output_filename):
    """Extract raw payload from IM4P file"""
    info = parse_im4p(filename)
    if info:
        with open(filename, 'rb') as f:
            f.seek(info['payload_offset'])
            payload = f.read(info['payload_size'])

        with open(output_filename, 'wb') as f:
            f.write(payload)

        print(f"\n[+] Extracted payload to: {output_filename}")
        return True
    return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <im4p_file> [output_file]")
        print(f"       {sys.argv[0]} <im4p_file>              - Parse and display info")
        print(f"       {sys.argv[0]} <im4p_file> <output>     - Extract payload")
        sys.exit(1)

    input_file = sys.argv[1]

    if len(sys.argv) >= 3:
        extract_payload(input_file, sys.argv[2])
    else:
        parse_im4p(input_file)
