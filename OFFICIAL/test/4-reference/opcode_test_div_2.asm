addiu $s0, $0, 0x123
addiu $s1, $0, 0x123
div $s0, $s1

mfhi $v0


# assert($v0 == 0x0000)
