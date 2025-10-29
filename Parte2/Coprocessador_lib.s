.section .data
DEV_MEM:         .asciz "/dev/mem"
FPGA_SPAN:       .word 0x1000
FPGA_ADDRS:      .space 4
FILE_DESCRIPTOR: .space 4
FPGA_BRIDGE:     .word 0xFF200000         @ Base LWHPS2FPGA

PIO_DATA_OUT:    .equ 0x00
PIO_DATA_IN:     .equ 0x04
PIO_CONTROL:     .equ 0x08
PIO_STATUS:      .equ 0x0C
PIO_ADDRESS:     .equ 0x10

.section .text
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

iniciarCoprocessor:
    push {r4, r7, lr}
    LDR R0, =DEV_MEM
    MOV R1, #2
    MOV R2, #0
    MOV R7, #5
    SVC 0
    LDR R1, =FILE_DESCRIPTOR
    STR R0, [R1]
    MOV R4, R0
    MOV R0, #0
    LDR R1, =FPGA_SPAN
    LDR R1, [R1]
    MOV R2, #3
    MOV R3, #1
    LDR R5, =FPGA_BRIDGE
    LDR R5, [R5]
    MOV R7, #192
    SVC 0
    LDR R1, =FPGA_ADDRS
    STR R0, [R1]
    pop {r4, r7, lr}
    bx lr

encerrarCoprocessor:
    push {r4, r7, lr}
    LDR R0, =FPGA_ADDRS
    LDR R0, [R0]
    LDR R1, =FPGA_SPAN
    LDR R1, [R1]
    MOV R7, #91
    SVC 0
    LDR R0, =FILE_DESCRIPTOR
    LDR R0, [R0]
    MOV R7, #6
    SVC 0
    pop {r4, r7, lr}
    bx lr

write_pio:
    @ r0=offset, r1=valor
    push {r2, lr}
    LDR R2, =FPGA_ADDRS
    LDR R2, [R2]
    STR R1, [R2, R0]
    pop {r2, lr}
    bx lr

read_pio:
    @ r0=offset  --> retorna em r0
    push {r2, lr}
    LDR R2, =FPGA_ADDRS
    LDR R2, [R2]
    LDR R0, [R2, R0]
    pop {r2, lr}
    bx lr

resetCoprocessor:
    push {r1, lr}
    MOV R0, #PIO_CONTROL
    MOV R1, #0x00000000
    BL write_pio
    MOV R0, #PIO_CONTROL
    MOV R1, #0x80000000
    BL write_pio
    pop {r1, lr}
    bx lr

configurar_algoritmo_zoom:
    @ r0=algoritmo (2 bits), r1=zoom (3 bits)
    push {r2, r3, lr}
    MOV R2, R1
    LSL R2, R2, #13             @ zoom_level para bits 15:13
    MOV R3, R0
    LSL R3, R3, #11             @ algorithm para bits 12:11
    ORR R2, R2, R3              @ prepara word de dados
    MOV R0, #PIO_CONTROL
    MOV R1, #(0x80000000|0x0C)
    BL write_pio
    MOV R0, #PIO_DATA_OUT
    MOV R1, R2
    BL write_pio
    MOV R0, #PIO_CONTROL
    MOV R1, #(0x80000000|0x04)
    BL write_pio
    pop {r2, r3, lr}
    bx lr

escrever_pixel:
    @ r0=address, r1=pixel
    push {r2, r3, lr}
    MOV R2, R0
    MOV R3, R1
    MOV R0, #PIO_ADDRESS
    MOV R1, R2
    BL  write_pio
    MOV R0, #PIO_DATA_OUT
    MOV R1, R3
    BL  write_pio
    MOV R0, #PIO_CONTROL
    MOV R1, #(0x80000000|0x300)
    BL  write_pio
    MOV R1, #(0x80000000|0x100)
    BL  write_pio
    pop {r2, r3, lr}
    bx lr

start_processing:
    push {r1, lr}
    MOV R0, #PIO_CONTROL
    MOV R1, #(0x80000000|0x0E)
    BL  write_pio
    MOV R0, #PIO_DATA_OUT
    MOV R1, #1
    BL  write_pio
    MOV R0, #PIO_CONTROL
    MOV R1, #(0x80000000|0x05)
    BL  write_pio
    pop {r1, lr}
    bx lr

aguardar_processamento:
    push {r1, lr}
    MOV R0, #PIO_STATUS
ps_wait:
    BL   read_pio
    TST  R0, #0x08
    BEQ  ps_wait
    pop {r1, lr}
    bx lr

.global main
.type main, %function

main:
    BL iniciarCoprocessor
    BL resetCoprocessor
    MOV R0, #1
    MOV R1, #4
    BL configurar_algoritmo_zoom
    MOV R0, #0
    MOV R1, #100
    BL escrever_pixel
    MOV R0, #5
    MOV R1, #200
    BL escrever_pixel
    MOV R0, #60
    MOV R1, #128
    BL escrever_pixel
    BL start_processing
    BL aguardar_processamento

loop_fim:
    B loop_fim