addiu t0 $0 0x23DA
addiu s0 $0 0x0020
sb t0 0x0000(s0)
jr $0
lw v0 0x0000(s0)

.data
00 00 00 F3
04 00 00 F3
08 00 00 F3
12 00 00 F3
16 00 00 F3
20 00 00 F3
24 00 00 F3
28 00 00 F3
32 00 00 F3
36 00 00 F3
40 00 00 F3
44 00 00 00