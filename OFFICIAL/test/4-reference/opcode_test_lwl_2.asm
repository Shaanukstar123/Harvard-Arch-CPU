lui t0 0x0102
lui t1 0x1234
addiu t1 $0 0x5678
sw t1 0x104($0)
sw t0 0x108($0)
lwl v0 0x107($0)
lwr v0 0x10a($0)
addiu t1 $0 0x0
jr $0
