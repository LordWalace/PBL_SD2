# README - Documentação Técnica do Projeto PBL_SD2

## Sumário
1. [Visão Geral do Sistema](#visão-geral-do-sistema)
2. [Arquitetura FPGA (Verilog)](#arquitetura-fpga-verilog)
   - [Estrutura de Módulos](#estrutura-de-módulos)
   - [Interfaces de Comunicação](#interfaces-de-comunicação)
   - [Blocos Funcionais](#blocos-funcionais)
3. [Arquitetura HPS (C)](#arquitetura-hps-c)
   - [Estrutura do Código C](#estrutura-do-código-c)
   - [Mapeamento de Memória](#mapeamento-de-memória)
4. [Integração HPS-FPGA](#integração-hps-fpga)
   - [Bridges de Comunicação](#bridges-de-comunicação)
   - [Fluxo de Dados](#fluxo-de-dados)
   - [Protocolo de Comunicação](#protocolo-de-comunicação)
5. [Referências](#referências)

---

## Visão Geral do Sistema

Este projeto implementa um sistema **System-on-Chip (SoC)** utilizando a placa **DE1-SoC** da Terasic, que integra um **FPGA Cyclone V** com um **Hard Processor System (HPS)** baseado em **ARM Cortex-A9**. A arquitetura divide as responsabilidades entre:

- **FPGA (Fabric)**: Implementação de lógica de hardware personalizada em Verilog para processamento paralelo, controle de periféricos e gerenciamento de dados em tempo real.
- **HPS (Hard Processor System)**: Processador ARM executando código em C (possivelmente sobre Linux) para gerenciamento de alto nível, interface com usuário e controle do sistema.

A comunicação entre HPS e FPGA é realizada através de **bridges AXI/Avalon**, permitindo transferência de dados e comandos via interface memory-mapped.

---

## Arquitetura FPGA (Verilog)

### Estrutura de Módulos

A implementação FPGA típica em projetos DE1-SoC segue uma hierarquia modular:

#### **Módulo Top-Level**
O módulo principal (`top.v` ou similar) instancia e interconecta todos os submódulos:
- **Gerenciamento de Clock**: PLLs para geração de clocks síncronos
- **Reset Logic**: Lógica de reset síncrono/assíncrono
- **Interface HPS**: Sinais Avalon Memory-Mapped para bridges
- **Periféricos**: LEDs, switches, displays 7-segmentos, GPIO

```verilog
module top(
    // Clock e Reset
    input wire CLOCK_50,
    input wire [3:0] KEY,
    
    // Periféricos FPGA
    output wire [9:0] LEDR,
    input wire [9:0] SW,
    output wire [6:0] HEX0, HEX1,
    
    // Interface HPS (Avalon MM Slave)
    input wire [15:0] avs_address,
    input wire avs_write,
    input wire avs_read,
    input wire [31:0] avs_writedata,
    output reg [31:0] avs_readdata,
    output wire avs_waitrequest
);
```

#### **Blocos de Controle**
**State Machines (FSMs)**: Controladores de estado implementados com always blocks:
```verilog
// Registrador de estado
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

// Lógica combinacional para próximo estado
always @(*) begin
    case (current_state)
        IDLE: begin
            if (start_signal)
                next_state = PROCESS;
            else
                next_state = IDLE;
        end
        PROCESS: begin
            if (done_signal)
                next_state = IDLE;
            else
                next_state = PROCESS;
        end
    endcase
end
```

#### **Registradores Memory-Mapped**
Registradores acessíveis via interface Avalon:
```verilog
// Decodificação de endereços
always @(posedge clk) begin
    if (avs_write) begin
        case (avs_address[7:0])
            8'h00: control_reg <= avs_writedata;
            8'h04: data_reg <= avs_writedata;
            8'h08: config_reg <= avs_writedata;
        endcase
    end
end

// Lógica de leitura
always @(*) begin
    case (avs_address[7:0])
        8'h00: avs_readdata = status_reg;
        8'h04: avs_readdata = result_reg;
        8'h08: avs_readdata = counter_reg;
        default: avs_readdata = 32'h00000000;
    endcase
end
```

### Interfaces de Comunicação

#### **Interface Avalon Memory-Mapped Slave**
A interface padrão para comunicação com HPS inclui:

| Sinal | Direção | Descrição |
|-------|---------|-----------|
| `avs_address` | Entrada | Endereço do registrador (word-aligned) |
| `avs_write` | Entrada | Sinal de escrita (1 = escrever) |
| `avs_read` | Entrada | Sinal de leitura (1 = ler) |
| `avs_writedata` | Entrada | Dados a serem escritos (32 bits) |
| `avs_readdata` | Saída | Dados lidos (32 bits) |
| `avs_waitrequest` | Saída | Sinal de espera (1 = ocupado) |
| `avs_readdatavalid` | Saída | Dados de leitura válidos (para leituras pipelined) |

**Protocolo de Transação:**
1. **Escrita**:
   - HPS asserta `avs_write` e apresenta `avs_address` e `avs_writedata`
   - FPGA captura dados se `avs_waitrequest = 0`
   - Transação completa em 1 ciclo (se sem wait)

2. **Leitura**:
   - HPS asserta `avs_read` e apresenta `avs_address`
   - FPGA responde com `avs_readdata` quando `avs_readdatavalid = 1`
   - Pode ter latência variável (pipelined)

### Blocos Funcionais

#### **Processamento de Dados**
Módulos para operações específicas:
- **ALUs customizadas**: Operações aritméticas/lógicas especializadas
- **Buffers FIFO**: Armazenamento temporário e sincronização entre domínios de clock
- **DMA Controllers**: Transferência direta de memória para alto throughput

#### **Controle de Periféricos**
- **GPIO Controllers**: Controle de pinos de entrada/saída
- **PWM Generators**: Geração de sinais PWM para controle de motores/LEDs
- **Serial Interfaces**: UART, SPI, I2C implementados em hardware

#### **Sincronização de Clock**
```verilog
// PLL para geração de múltiplos clocks
pll_system pll_inst (
    .refclk(CLOCK_50),      // 50 MHz input
    .rst(~KEY[0]),
    .outclk_0(clk_100mhz),  // 100 MHz para lógica rápida
    .outclk_1(clk_25mhz),   // 25 MHz para VGA
    .locked(pll_locked)
);
```

---

## Arquitetura HPS (C)

### Estrutura do Código C

#### **Inicialização do Sistema**
```c
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>

// Definições de endereços base (do hps_0.h gerado pelo Qsys)
#define HW_REGS_BASE 0xFF200000  // Base do Lightweight HPS-to-FPGA
#define HW_REGS_SPAN 0x00200000  // 2MB de espaço de endereçamento
#define HW_REGS_MASK (HW_REGS_SPAN - 1)

// Offsets dos componentes FPGA (definidos no Platform Designer)
#define LED_PIO_BASE 0x00000000
#define SW_PIO_BASE  0x00000040
#define CUSTOM_IP_BASE 0x00001000

int main(void) {
    int fd;
    void *virtual_base;
    volatile uint32_t *h2p_lw_led_addr;
    volatile uint32_t *h2p_lw_sw_addr;
    
    // Abrir /dev/mem para acesso à memória física
    if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
        printf("ERROR: could not open /dev/mem\n");
        return -1;
    }
    
    // Mapear região da memória física para espaço virtual
    virtual_base = mmap(NULL, HW_REGS_SPAN, 
                       (PROT_READ | PROT_WRITE), 
                       MAP_SHARED, fd, HW_REGS_BASE);
    
    if (virtual_base == MAP_FAILED) {
        printf("ERROR: mmap() failed\n");
        close(fd);
        return -1;
    }
    
    // Calcular endereços virtuais dos componentes
    h2p_lw_led_addr = virtual_base + 
                      ((unsigned long)(HW_REGS_BASE + LED_PIO_BASE) & 
                       (unsigned long)(HW_REGS_MASK));
    h2p_lw_sw_addr = virtual_base + 
                     ((unsigned long)(HW_REGS_BASE + SW_PIO_BASE) & 
                      (unsigned long)(HW_REGS_MASK));
    
    // Exemplo de interação com FPGA
    uint32_t sw_value = *h2p_lw_sw_addr;  // Ler switches
    *h2p_lw_led_addr = sw_value;          // Escrever nos LEDs
    
    // Limpeza
    if (munmap(virtual_base, HW_REGS_SPAN) != 0) {
        printf("ERROR: munmap() failed\n");
    }
    close(fd);
    return 0;
}
```

### Mapeamento de Memória

#### **Processo de Memory Mapping**
1. **Abertura de /dev/mem**: Arquivo especial que representa a memória física do sistema
2. **mmap()**: Mapeia região física para espaço de endereçamento virtual do processo
3. **Acesso via Ponteiros**: Leitura/escrita através de ponteiros voláteis
4. **munmap()**: Libera o mapeamento quando não mais necessário

#### **Cálculo de Endereços**
```
Endereço Virtual = virtual_base + 
                   ((Base Bridge + Offset Componente) & Máscara)
```

Exemplo:
```
LED_ADDR_VIRTUAL = virtual_base + 
                   ((0xFF200000 + 0x00000000) & 0x001FFFFF)
                 = virtual_base + 0x00000000
```

#### **Estruturas de Dados**
```c
// Estrutura para controle de IP customizado
typedef struct {
    volatile uint32_t control;     // +0x00: Registrador de controle
    volatile uint32_t status;      // +0x04: Registrador de status
    volatile uint32_t data_in;     // +0x08: Dados de entrada
    volatile uint32_t data_out;    // +0x0C: Dados de saída
    volatile uint32_t config[4];   // +0x10-0x1C: Registradores de configuração
} custom_ip_regs_t;

// Uso:
custom_ip_regs_t *ip = (custom_ip_regs_t *)(virtual_base + CUSTOM_IP_BASE);
ip->control = 0x00000001;  // Ativar IP
while (!(ip->status & 0x01)); // Esperar conclusão
uint32_t result = ip->data_out; // Ler resultado
```

---

## Integração HPS-FPGA

### Bridges de Comunicação

A arquitetura Cyclone V SoC fornece três bridges principais:

#### **1. Lightweight HPS-to-FPGA Bridge (LWH2F)**
- **Endereço Base**: 0xFF200000
- **Largura de Dados**: 32 bits
- **Espaço de Endereçamento**: 2 MB (0xFF200000 - 0xFF3FFFFF)
- **Uso Típico**: Controle de periféricos simples (LEDs, switches, PIOs)
- **Latência**: Baixa (ideal para polling)
- **Mestre**: ARM Cortex-A9

```
ARM CPU → L3 Interconnect → LWH2F Bridge → Avalon Interconnect → FPGA Slaves
```

#### **2. HPS-to-FPGA Bridge (H2F)**
- **Endereço Base**: Configurável via Platform Designer
- **Largura de Dados**: 32/64/128 bits (configurável)
- **Espaço de Endereçamento**: Até 960 MB
- **Uso Típico**: Transferências de dados de alto volume
- **Latência**: Moderada
- **Suporte**: Burst transactions, cache coherency

#### **3. FPGA-to-HPS Bridge (F2H)**
- **Direção**: FPGA → HPS (FPGA como mestre)
- **Uso Típico**: DMA, acesso à memória DDR3 do HPS
- **Configuração**: FPGA precisa implementar interface Avalon Master

### Fluxo de Dados

#### **Habilitação das Bridges**
Antes de usar as bridges, é necessário habilitá-las:

**Via Linux (Device Tree Overlay)**:
```bash
echo 1 > /sys/class/fpga-bridge/lwhps2fpga/enable
echo 1 > /sys/class/fpga-bridge/hps2fpga/enable
```

**Via Registrador de Hardware** (endereço 0xFFD0501C):
```c
#define RSTMGR_BRGMODRST 0xFFD0501C
volatile uint32_t *rst_reg = (uint32_t *)RSTMGR_BRGMODRST;
*rst_reg &= ~0x07;  // Limpar bits [2:0] para habilitar bridges
```

#### **Sequência de Comunicação Típica**

**1. HPS envia comando para FPGA**:
```c
// C (HPS)
volatile uint32_t *fpga_cmd = virtual_base + CMD_REG_OFFSET;
volatile uint32_t *fpga_data = virtual_base + DATA_REG_OFFSET;

*fpga_cmd = 0x01;        // Comando: Iniciar processamento
*fpga_data = input_data; // Dados de entrada
```

```verilog
// Verilog (FPGA)
always @(posedge clk) begin
    if (avs_write && avs_address == CMD_ADDR) begin
        command <= avs_writedata;
        start_processing <= 1'b1;
    end
    if (avs_write && avs_address == DATA_ADDR) begin
        input_buffer <= avs_writedata;
    end
end
```

**2. FPGA processa dados**:
```verilog
// State machine para processamento
always @(posedge clk) begin
    case (state)
        IDLE: begin
            if (start_processing) begin
                state <= COMPUTE;
                busy <= 1'b1;
            end
        end
        COMPUTE: begin
            // Operações de processamento
            result <= input_buffer * coefficient;
            if (computation_done) begin
                state <= DONE;
                busy <= 1'b0;
            end
        end
        DONE: begin
            result_valid <= 1'b1;
            state <= IDLE;
        end
    endcase
end
```

**3. HPS lê resultado**:
```c
// C (HPS)
volatile uint32_t *fpga_status = virtual_base + STATUS_REG_OFFSET;
volatile uint32_t *fpga_result = virtual_base + RESULT_REG_OFFSET;

// Polling até FPGA concluir
while (*fpga_status & 0x01); // Bit 0 = busy

// Ler resultado
uint32_t output_data = *fpga_result;
printf("FPGA Result: 0x%08X\n", output_data);
```

### Protocolo de Comunicação

#### **Registradores de Controle (Padrão)**
| Offset | Nome | R/W | Descrição |
|--------|------|-----|-----------|
| 0x00 | CONTROL | W | Bits de controle (start, reset, mode) |
| 0x04 | STATUS | R | Flags de status (busy, error, done) |
| 0x08 | DATA_IN | W | Dados de entrada |
| 0x0C | DATA_OUT | R | Dados de saída |
| 0x10 | CONFIG | R/W | Parâmetros de configuração |
| 0x14 | IRQ_MASK | R/W | Máscara de interrupções |

#### **Sincronização**
**Polling (Simples)**:
```c
// HPS espera FPGA
while (status_reg & BUSY_BIT);
```

**Interrupt-Driven (Eficiente)**:
```c
// Configurar IRQ handler no Linux
// FPGA asserta sinal de interrupção quando concluir
// Kernel chama handler registrado
```

```verilog
// FPGA gera interrupção
always @(posedge clk) begin
    if (state == DONE) begin
        irq_output <= 1'b1;
    end else begin
        irq_output <= 1'b0;
    end
end
```

#### **Transferências de Dados em Bloco**
Para transferências grandes, usar DMA ou FIFO:

```c
// HPS escreve em FIFO via loop
for (int i = 0; i < data_size; i++) {
    while (*fifo_status & FIFO_FULL); // Esperar espaço
    *fifo_write = data_buffer[i];
}
```

```verilog
// FPGA consome FIFO
fifo_h2f fifo_inst (
    .clock(clk),
    .data(avs_writedata),
    .wrreq(avs_write && avs_address == FIFO_ADDR),
    .rdreq(fifo_read_enable),
    .q(fifo_data_out),
    .empty(fifo_empty),
    .full(fifo_full)
);
```

---

## Referências

### Documentação Intel/Altera
1. [Cyclone V Hard Processor System Technical Reference Manual](https://www.intel.com/content/www/us/en/programmable/hps/cyclone-v/hps.html)
2. [DE1-SoC User Manual - Terasic](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=165&No=836)
3. [Intel FPGA University Program - DE1-SoC Computer Manual](https://fpgacademy.org/)
4. [Avalon Interface Specifications](https://www.intel.com/content/www/us/en/docs/programmable/683091/current/introduction-to-the-interface-specifications.html)

### Tutoriais Práticos
5. [Cornell ECE5760 - FPGA/HPS Communication](https://people.ece.cornell.edu/land/courses/ece5760/)
6. [HPS+FPGA Systems on DE1-SoC Board - dejazzer.com](https://dejazzer.com/)
7. [Using Linux on the DE1-SoC](https://fpgacademy.org/tutorials.html)

### Exemplos de Código
8. [Exchange data packets HPS-FPGA - GitHub](https://github.com/)
9. [CycloneV HPS FIFO Example - RocketBoards](https://rocketboards.org/)
10. [Memory-mapped I/O - Wikipedia](https://en.wikipedia.org/wiki/Memory-mapped_I/O)

---

## Notas Finais

Esta documentação apresenta os conceitos teóricos fundamentais para entender a arquitetura de sistemas SoC baseados em DE1-SoC. Para implementação específica do projeto **PBL_SD2**, seria necessário:

1. Acesso aos arquivos do repositório (`.v`, `.sv`, `.c`, `.h`)
2. Diagramas de blocos do Platform Designer/Qsys (`.qsys`)
3. Especificações dos componentes customizados
4. Tabela de endereçamento memory-mapped completa

A estrutura aqui apresentada segue as melhores práticas da indústria e é aplicável à maioria dos projetos DE1-SoC com comunicação HPS-FPGA via bridges Avalon/AXI.
