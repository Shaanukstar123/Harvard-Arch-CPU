addiu v1 $0 0x2E7
sw v1 0x100(v1)
lw v0 0x100(v1)
jr $0

# v0 = 743 == 0x2E7
