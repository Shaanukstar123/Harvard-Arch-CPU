addiu s1 s1 0x2
addiu s2 s2 0x1
bne s1 s2 3
sll $0 $0 0x0
jr $0
addiu v0 v0 0xabcd
j 0x3f00001
addiu v0 v0 0x1
jr $0
addiu v0 $0 0xffff