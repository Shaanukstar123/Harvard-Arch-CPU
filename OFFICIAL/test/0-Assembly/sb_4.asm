addiu t0 $0 0x23DA
addiu s0 $0 0x106
sw $0 0x000D(s0)
sb t0 0x000D(s0)
jr $0
lw v0 0x000C(s0)
