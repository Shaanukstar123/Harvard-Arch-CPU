li $s1.0x2A
lI $s2.0x2B
mult $s1 $s2
mflo $ v0

assert v0 == 0x70E