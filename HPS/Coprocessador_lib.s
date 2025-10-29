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

DEV_MEM:          .asciz "/dev/mem"
FPGA_SPAN:        .word 0x1000      @ tamanho mapeado 4KB
FPGA_ADDRS:       .word 0
FILE_DESCRIPTOR:  .word 0
FPGA_BRIDGE:      .word 0xFF200000  @ base bridge LWHPS2FPGA

@ --- OFFSETS DOS 3 PIOS (UNIDIRECIONAIS) ---
.equ PIO_DATA_IN,    0x00  @ HPS -> FPGA (Dados)
.equ PIO_DATA_OUT,   0x10  @ FPGA -> HPS (Status + Dados de Leitura)
.equ PIO_CONTROL_IN, 0x20  @ HPS -> FPGA (Controlo + Endereço ImgRam)

@ --- CONSTANTES DO PROTOCOLO ENABLE/DONE --- Caso seja necessário ajustar os bits, tu faz aqui
.equ ENABLE_BIT,    (1 << 30)
.equ RESET_N_BIT,   (1 << 31)
.equ DONE_BIT_MASK, (1 << 1) @ Bit [1] no PIO_DATA_OUT

@ Comandos (bits [20:15] do PIO_CONTROL_IN)
.equ CMD_WRITE_IMGRAM_VAL,  0x01
.equ CMD_WRITE_REGCTRL_VAL, 0x02
.equ CMD_START_PROCESS_VAL, 0x04

.equ CMD_WRITE_IMGRAM,  (CMD_WRITE_IMGRAM_VAL  << 15)
.equ CMD_WRITE_REGCTRL, (CMD_WRITE_REGCTRL_VAL << 15)
.equ CMD_START_PROCESS, (CMD_START_PROCESS_VAL << 15)


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

@ --- FUNÇÃO DE DELAY ---
delay_loop:
    push {r0}
    mov  r0, #0x1FFFF @ (Contador reduzido, ajuste se necessário)
delay_inner:
    subs r0, r0, #1
    bne  delay_inner
    pop  {r0}
    bx   lr

@ iniciarCoprocessor (Sem alterações)
iniciarCoprocessor:
    push {r4, r5, r7, lr}
    movw    r0, #:lower16:DEV_MEM
    movt    r0, #:upper16:DEV_MEM
    mov     r1, #2          @ O_RDWR
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
    mov     r2, #3          @ PROT_READ | PROT_WRITE
    mov     r3, #1          @ MAP_SHARED
    movw    r5, #:lower16:FPGA_BRIDGE
    movt    r5, #:upper16:FPGA_BRIDGE
    ldr     r5, [r5]
    lsr     r5, r5, #12     @ offset em páginas
    mov     r6, r4
    mov     r7, #192        @ mmap2
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
    mov     r7, #91         @ munmap
    svc     0
    movw    r0, #:lower16:FILE_DESCRIPTOR
    movt    r0, #:upper16:FILE_DESCRIPTOR
    ldr     r0, [r0]
    mov     r7, #6          @ close
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

@ resetCoprocessor (MODIFICADO para usar constantes)
resetCoprocessor:
    push {r1, lr}
    ldr     r0, =PIO_CONTROL_IN
    mov     r1, #0x00000000       @ Ativa o reset (bit 31=0)
    bl      write_pio
    
    bl      delay_loop            @ <<< ATRASO ADICIONADO
    
    ldr     r0, =PIO_CONTROL_IN
    ldr     r1, =RESET_N_BIT      @ Desativa o reset (bit 31=1)
    bl      write_pio
    
    bl      delay_loop            @ <<< ATRASO ADICIONADO
    
    pop {r1, lr}
    bx lr

@ configurar_algoritmo_zoom (MODIFICADO para novo protocolo)
@ r0=algoritmo, r1=zoom
configurar_algoritmo_zoom:
    push {r2, r3, r4, lr}
    
    @ Prepara a palavra de dados (para PIO_DATA_IN)
    mov     r2, r1                @ r2 = zoom (ex: 4)
    lsl     r2, r2, #2            @ Alinha zoom para bits [4:2]
    mov     r3, r0                @ r3 = algoritmo (ex: 1)
    orr     r2, r2, r3            @ Combina dados (ex: 0b10001 = 0x11)
    
    @ 1. Escreve os dados (zoom/algoritmo) em PIO_DATA_IN
    ldr     r0, =PIO_DATA_IN
    mov     r1, r2
    bl      write_pio
    
    @ Prepara a palavra de controlo (CMD + Addr 0)
    @ Endereço 0x00 para registo de controlo (bits [1:0])
    ldr     r4, =(RESET_N_BIT | CMD_WRITE_REGCTRL | 0x00)
    
    @ 2. Envia pulso de ENABLE (ENABLE=1)
    ldr     r0, =PIO_CONTROL_IN
    orr     r1, r4, #ENABLE_BIT   @ Adiciona bit de ENABLE
    bl      write_pio
    
    bl      delay_loop            @ <<< Atraso para o pulso
    
    @ 3. Termina o pulso (ENABLE=0)
    ldr     r0, =PIO_CONTROL_IN
    mov     r1, r4                @ Envia palavra de controlo (sem ENABLE)
    bl      write_pio
    
    pop {r2, r3, r4, lr}
    bx lr

@ escrever_pixel (MODIFICADO para novo protocolo)
@ r0=address, r1=pixel
escrever_pixel:
    push {r2, r3, r4, lr}
    mov     r2, r0                @ r2 = endereço (ex: 5)
    mov     r3, r1                @ r3 = pixel (ex: 100)
    
    @ 1. Escreve o dado (pixel) em PIO_DATA_IN
    ldr     r0, =PIO_DATA_IN
    mov     r1, r3
    bl      write_pio
    
    @ Prepara a palavra de controlo (CMD + Addr)
    ldr     r4, =(RESET_N_BIT | CMD_WRITE_IMGRAM)
    orr     r4, r4, r2            @ Combina comando com endereço [14:0]
    
    @ 2. Envia pulso de ENABLE (ENABLE=1)
    ldr     r0, =PIO_CONTROL_IN
    orr     r1, r4, #ENABLE_BIT   @ Adiciona bit de ENABLE
    bl      write_pio
    
    bl      delay_loop            @ <<< Atraso para o pulso
    
    @ 3. Termina o pulso (ENABLE=0)
    ldr     r0, =PIO_CONTROL_IN
    mov     r1, r4                @ Envia palavra de controlo (sem ENABLE)
    bl      write_pio
    
    pop {r2, r3, r4, lr}
    bx lr

@ start_processing (MODIFICADO para novo protocolo)
start_processing:
    push {r1, r4, lr}
    
    @ 1. (Escrever em PIO_DATA_IN não é mais necessário)
    
    @ Prepara a palavra de controlo (só o CMD)
    ldr     r4, =(RESET_N_BIT | CMD_START_PROCESS)
    
    @ 2. Envia pulso de ENABLE (ENABLE=1)
    ldr     r0, =PIO_CONTROL_IN
    orr     r1, r4, #ENABLE_BIT   @ Adiciona bit de ENABLE
    bl      write_pio
    
    bl      delay_loop            @ <<< Atraso para o pulso
    
    @ 3. Termina o pulso (ENABLE=0)
    ldr     r0, =PIO_CONTROL_IN
    mov     r1, r4                @ Envia palavra de controlo (sem ENABLE)
    bl      write_pio
    
    pop {r1, r4, lr}
    bx lr

@ aguardar_processamento (MODIFICADO para o bit DONE correto)
aguardar_processamento:
    push {r1, lr}
    ldr     r0, =PIO_DATA_OUT
ps_wait:
    bl      read_pio
    tst     r0, #DONE_BIT_MASK    @ <<< NOVO (bit 1)
    beq     ps_wait
    pop {r1, lr}
    bx lr

@ main de teste
@ main:
@     bl iniciarCoprocessor
@     bl resetCoprocessor
@     mov     r0, #1
@     mov     r1, #4
@     bl configurar_algoritmo_zoom
@     mov     r0, #0
@     mov     r1, #100
@     bl escrever_pixel
@     mov     r0, #5
@     mov     r1, #200
@     bl escrever_pixel
@     mov     r0, #60
@     mov     r1, #128
@     bl escrever_pixel
@     bl start_processing
@     bl aguardar_processamento
@
@ loop_fim:
@     b loop_fim
