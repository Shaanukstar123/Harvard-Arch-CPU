lui s0 0x4000
addiu s1 s1 0x40
sra s0 s0 0x8
beq s0 s1 2
sll $0 $0 0x0
j 0x3f00002
addiu v0 v0 0x1
jr $0
sll $0 $0 0x0 