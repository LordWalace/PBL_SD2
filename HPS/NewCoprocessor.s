.syntax unified
.cpu cortex-a9
.arch armv7-a

.section .data
.balign 4
.global DEV_MEM
.global FPGA_SPAN
.global FPGA_ADDRS
.global FILE_DESCRIPTOR
.global FPGA_BRIDGE

DEV_MEM:         .asciz "/dev/mem"
FPGA_SPAN:       .word 0x1000         @ tamanho mapeado 4KB
FPGA_ADDRS:      .word 0
FILE_DESCRIPTOR: .word 0
FPGA_BRIDGE:     .word 0xFF200000     @ base bridge LWHPS2FPGA

@ --- OFFSETS DOS 3 PIOS (UNIDIRECIONAIS) ---
@ Endereços corretos fornecidos pelo utilizador
.equ PIO_DATA_IN,    0x00  @ HPS -> FPGA (Dados)
.equ PIO_DATA_OUT,   0x10  @ FPGA -> HPS (Status + Dados de Leitura)
.equ PIO_CONTROL_IN,  0x20  @ HPS -> FPGA (Controlo + Endereço ImgRam)
@ --- FIM DOS OFFSETS ---

.section .text
.balign 4
.global iniciarCoprocessor
.type iniciarCoprocessor, %function
.global encerrarCoprocessor
.type encerrarCoprocessor, %function
.global write_pio
.type write_pio, %function
.global read_pio
.type read_pio, %function
.global configurar_algoritmo_zoom
.type configurar_algoritmo_zoom, %function
.global escrever_pixel
.type escrever_pixel, %function
.global start_processing
.type start_processing, %function
.global aguardar_processamento
.type aguardar_processamento, %function
.global resetCoprocessor
.type resetCoprocessor, %function

@ iniciarCoprocessor (Sem alterações)
iniciarCoprocessor:
    push {r4, r5, r7, lr}
    movw    r0, #:lower16:DEV_MEM
    movt    r0, #:upper16:DEV_MEM
    mov     r1, #2           @ O_RDWR
    mov     r2, #0
    mov     r7, #5
    svc     0
    movw    r1, #:lower16:FILE_DESCRIPTOR
    movt    r1, #:upper16:FILE_DESCRIPTOR
    str     r0, [r1]
    mov     r4, r0
    mov     r0, #0
    movw    r1, #:lower16:FPGA_SPAN
    movt    r1, #:upper16:FPGA_SPAN
    ldr     r1, [r1]
    mov     r2, #3           @ PROT_READ | PROT_WRITE
    mov     r3, #1           @ MAP_SHARED
    movw    r5, #:lower16:FPGA_BRIDGE
    movt    r5, #:upper16:FPGA_BRIDGE
    ldr     r5, [r5]
    lsr     r5, r5, #12      @ offset em páginas
    mov     r6, r4
    mov     r7, #192         @ mmap2
    svc     0
    movw    r1, #:lower16:FPGA_ADDRS
    movt    r1, #:upper16:FPGA_ADDRS
    str     r0, [r1]
    pop {r4, r5, r7, lr}
    bx lr

@ encerrarCoprocessor (Sem alterações)
encerrarCoprocessor:
    push {r4, r7, lr}
    movw    r0, #:lower16:FPGA_ADDRS
    movt    r0, #:upper16:FPGA_ADDRS
    ldr     r0, [r0]
    movw    r1, #:lower16:FPGA_SPAN
    movt    r1, #:upper16:FPGA_SPAN
    ldr     r1, [r1]
    mov     r7, #91          @ munmap
    svc     0
    movw    r0, #:lower16:FILE_DESCRIPTOR
    movt    r0, #:upper16:FILE_DESCRIPTOR
    ldr     r0, [r0]
    mov     r7, #6           @ close
    svc     0
    pop {r4, r7, lr}
    bx lr

@ write_pio (Sem alterações)
write_pio:
    push {r2, lr}
    movw    r2, #:lower16:FPGA_ADDRS
    movt    r2, #:upper16:FPGA_ADDRS
    ldr     r2, [r2]
    add     r2, r2, r0
    str     r1, [r2]
    pop {r2, lr}
    bx lr

@ read_pio (Sem alterações)
read_pio:
    push {r2, lr}
    movw    r2, #:lower16:FPGA_ADDRS
    movt    r2, #:upper16:FPGA_ADDRS
    ldr     r2, [r2]
    add     r2, r2, r0
    ldr     r0, [r2]
    pop {r2, lr}
    bx lr

@ resetCoprocessor (Sem alterações)
resetCoprocessor:
    push {r1, lr}
    ldr     r0, =PIO_CONTROL_IN
    mov     r1, #0x00000000      @ Ativa o reset (bit 31=0)
    bl      write_pio
    ldr     r0, =PIO_CONTROL_IN
    ldr     r1, =0x80000000      @ Desativa o reset (bit 31=1)
    bl      write_pio
    pop {r1, lr}
    bx lr

@ configurar_algoritmo_zoom (CORRIGIDO)
@ r0=algoritmo, r1=zoom
configurar_algoritmo_zoom:
    push {r2, r3, r4, lr}
    
    @ Prepara a palavra de dados conforme RegisterController.v espera
    mov     r2, r1                  @ r2 = zoom (ex: 4)
    lsl     r2, r2, #2              @ CORRIGIDO: Alinha zoom para bits [4:2]
    mov     r3, r0                  @ r3 = algoritmo (ex: 1)
                                    @ (Não precisa de LSL, já está nos bits [1:0])
    orr     r2, r2, r3              @ Combina dados (ex: 0b10001 = 0x11)
    
    @ 1. Escreve os dados (zoom/algoritmo)
    ldr     r0, =PIO_DATA_IN
    mov     r1, r2
    bl      write_pio
    
    @ 2. Envia pulso de escrita para o RegisterController (Address 0)
    ldr     r0, =PIO_CONTROL_IN
    ldr     r4, =0x8000000C         @ Máscara: Reset_n(31)|WR(3)|CS(2)|Addr(0)
    mov     r1, r4
    bl      write_pio
    
    @ 3. Termina o pulso de escrita
    ldr     r0, =PIO_CONTROL_IN
    ldr     r4, =0x80000004         @ Máscara: Reset_n(31)|CS(2)|Addr(0)
    mov     r1, r4
    bl      write_pio
    
    pop {r2, r3, r4, lr}
    bx lr

@ escrever_pixel (Sem alterações)
escrever_pixel:
    push {r2, r3, r4, lr}
    mov     r2, r0               @ r2 = endereço (ex: 5)
    mov     r3, r1               @ r3 = pixel (ex: 100)
    
    @ 1. Escreve o dado (pixel) em PIO_DATA_IN
    ldr     r0, =PIO_DATA_IN
    mov     r1, r3
    bl      write_pio
    
    @ 2. Prepara o endereço alinhado (base) em r2
    lsl     r2, r2, #15          @ r2 = endereço_alinhado (ex: 0x000A8000)
    
    @ 3. Envia pulso de escrita (WR=1)
    ldr     r0, =PIO_CONTROL_IN
    ldr     r4, =0x80000300      @ Máscara: Reset_n(31)|WR_img(9)|CS_img(8)
    orr     r1, r2, r4           @ r1 = endereço_alinhado | Máscara ON
    bl      write_pio
    
    @ 4. Termina o pulso de escrita (WR=0)
    ldr     r0, =PIO_CONTROL_IN
    ldr     r4, =0x80000100      @ Máscara: Reset_n(31)|CS_img(8)
    orr     r1, r2, r4           @ r1 = endereço_alinhado | Máscara OFF
    bl      write_pio
    
    pop {r2, r3, r4, lr}
    bx lr

@ start_processing (Sem alterações)
start_processing:
    push {r1, r4, lr}
    
    @ 1. Escreve o dado '1' (start)
    ldr     r0, =PIO_DATA_IN
    mov     r1, #1
    bl      write_pio
    
    @ 2. Envia pulso de escrita para o RegisterController (Address 1)
    ldr     r0, =PIO_CONTROL_IN
    ldr     r4, =0x8000000D         @ Máscara: Reset_n(31)|WR(3)|CS(2)|Addr(1)
    mov     r1, r4
    bl      write_pio
    
    @ 3. Termina o pulso de escrita
    ldr     r0, =PIO_CONTROL_IN
    ldr     r4, =0x80000005         @ Máscara: Reset_n(31)|CS(2)|Addr(1)
    mov     r1, r4
    bl      write_pio
    
    pop {r1, r4, lr}
    bx lr

@ aguardar_processamento (Sem alterações)
aguardar_processamento:
    push {r1, lr}
    ldr     r0, =PIO_DATA_OUT
ps_wait:
    bl      read_pio
    tst     r0, #0x08
    beq     ps_wait
    pop {r1, lr}
    bx lr

@ main de teste (Sem alterações)
main:
    bl iniciarCoprocessor
    bl resetCoprocessor
    mov     r0, #1
    mov     r1, #4
    bl configurar_algoritmo_zoom
    mov     r0, #0
    mov     r1, #100
    bl escrever_pixel
    mov     r0, #5
    mov     r1, #200
    bl escrever_pixel
    mov     r0, #60
    mov     r1, #128
    bl escrever_pixel
    bl start_processing
    bl aguardar_processamento

loop_fim:
    b loop_fim
