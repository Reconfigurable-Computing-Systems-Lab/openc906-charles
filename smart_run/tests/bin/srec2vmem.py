#!/usr/bin/env python3
"""S-record -> .pat (vmem) converter, drop-in replacement for tests/bin/Srec2vmem
(a Linux x86-64 binary that cannot run on macOS).

Output: one 32-bit word per line, 8 lowercase hex digits, covering 4 consecutive
byte addresses in ascending order rebased to the word-aligned lowest address in
the S-record file. The LEFTMOST hex pair is the LOWEST byte address: tb.v's
$readmemh loaders write patword[31:24] into SRAM byte lane 0
(f_spsram_8388608x128: ram0 = D[7:0] = lowest byte address), so this layout is
what makes little-endian RV64 reads reconstruct the original bytes. Gaps between
records are zero-filled; a file with no data records yields a single 00000000.

Usage: srec2vmem.py <srecfile> <vmemfile>
"""
import sys


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: srec2vmem.py <srecfile> <vmemfile>")
    mem = {}
    with open(sys.argv[1]) as f:
        for line in f:
            line = line.strip()
            if len(line) < 4 or not line.startswith("S") or line[1] not in "123":
                continue
            alen = {"1": 2, "2": 3, "3": 4}[line[1]]
            count = int(line[2:4], 16)
            addr = int(line[4:4 + alen * 2], 16)
            n_data = count - alen - 1  # count covers addr + data + checksum
            start = 4 + alen * 2
            data_hex = line[start:start + n_data * 2]
            for i in range(0, len(data_hex), 2):
                mem[addr + i // 2] = int(data_hex[i:i + 2], 16)
    with open(sys.argv[2], "w") as out:
        if not mem:
            out.write("00000000\n")
            return
        base = min(mem) & ~0x3
        end = max(mem)
        for a in range(base, end + 1, 4):
            out.write("%02x%02x%02x%02x\n" % tuple(mem.get(a + k, 0) for k in range(4)))


if __name__ == "__main__":
    main()
