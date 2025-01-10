.globl plus, main

plus:
        add x0, x0, x1  // x0 = x0 + x1
        mov x2, x0      // x2 = x0
        ret

main:
        mov x0, 3       // x0 = 3
        mov x1, 4       // x1 = 4
        b plus          // call plus
        ret
