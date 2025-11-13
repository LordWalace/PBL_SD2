**Universidade Estadual de Feira de Santana (UEFS)**

**Disciplina:** Sistemas Digitais (TEC499) - 2025.2

**Equipe:** Luis Felipe Carneiro Pimentel e Walace de Jesus Venas

---
Coprocessador FPGA para Processamento de Imagens em Tons de Cinza
---

Sumário
=================
  * [1. Softwares Utilizados](#1-softwares-utilizados)
  * [2. Hardware Usado nos Testes](#2-hardware-usado-nos-testes))
  * [3. Arquitetura do Sistema](#3-arquitetura-do-sistema)
  * [4. Instalação e Configuração](#4-instalacão-e-configuração)


## Descrição do projeto.

A segunda etapa do projeto **Zoom Digital** Sistemas Digitais (MI) concentra-se na interação entre a unidade de processamento principal, o HPS (Hard Processor System), e o chip reconfigurável, o FPGA (Field Programmable Gate Array), ambos presentes na placa DE1-SoC. A conexão entre essas duas áreas foi estabelecida utilizando interfaces PIOs (Parallel Input/Output) customizadas, definidas pelo Platform Designer e integradas através da arquitetura de barramento AXI. Essa transmissão de dados otimizada entre os dois componentes viabiliza o encaminhamento de comandos, informações e sinais de feedback para a execução das tarefas de processamento de matrizes. 

O cooprocessador e sua implementação em verilog pode ser visualizado no [Repositório da etapa 1](https://github.com/LordWalace/PBL_SD1/blob/main/README.md).

<img src="imagens/fpga-hps.png"><br>
<strong>Conexão HPS ↔ FPGA via PIOs AXI</strong><br><br>


---

### 1. Softwares Utilizados.
- **IDEs de Desenvolvimento:** *Intel Quartus Prime Lite Edition (23.1std.0),Visual Studio Code*
- **Simulador:** *ModelSim - Intel FPGA Edition (2020.1)*
- **Linguganes de programação:*Verilog-2001*

---

### 2. Hardware Usado nos Testes.
- **Placa de Desenvolvimento:** Terasic DE1-SoC
- **FPGA:** Intel Cyclone V SE 5CSEMA5F31C6N
- **Memória de Vídeo (Frame Buffer):** RAM de dupla porta (76.800 palavras x 8 bits)
- **Monitor:** Philips VGA (640x480 @ 60Hz)

---

### 3. Arquitetura do Sistema

A arquitetura se baseia em uma divisão clara entre software e hardware para isolar o processamento de pixels das operações de deslocamento/zoom. A comunicação entre o HPS e o Coprocessador é realizada através de Barramentos PIO (Parallel Input/Output).

Nessa estapa do projeto fizemos uso de uma arquitetura externa para o desenvolvimento da 

#### 3.1. Blocos Principais.

| Bloco	| Descrição	| Implementação Principal |
| --- | --- | --- |
| Qsys System (soc_system) | Integra o processador ARM (HPS), módulos PIO, e lógicas auxiliares (clocks, reset) | Integração do processador |
| Coprocessador | Lógica dedicada para interpretar a ISA, gerenciar memória de imagem, e executar as operações de zoom. | Contém uma FSM e um datapath dedicado. |
| VGA Output | Interface para exibição das imagens ampliadas em um monitor padrão.	| Módulo da placa DE1-SoC |
| Barramentos PIO | Estruturas para troca de sinais de controle, endereço, dados e flags entre HPS e Coprocessador.	| Mapeado via Qsys. |


### 4. Funcionalidades e ISA.

O coprocessador implementa uma ISA enxuta com três classes de instrução, focadas em transferência de dados e execução de zoom:

| Classe | Descrição |
| --- | --- |
| LOAD	| Leitura de dado da memória de imagem. |
| STORE	| Escrita de dado na memória de imagem. | 
| ZOOM	| Execução da operação de ampliação/redução sobre uma região. |

#### 4.1. Formato da Instrução (Palavra de 32 bits).

| Bits	| Função |
| --- | --- |
| [2:0]	| Código da operação (OpCode) |
| [19:3]	| Endereço de memória|
| [28:21]	| Dado de entrada (apenas para STORE) |
| [31:29]	| Reservado |

#### 4.2. Algoritmos de Zoom

O algoritmo empregado é o "Nearest Neighbor" (Vizinho Mais Próximo). Ele é ideal para hardware embarcado por sua baixa complexidade e bom desempenho, realizando o zoom através da replicação de pixels conforme um fator definido.

---

### 5. Barramentos PIO e Sinais de Comunicação.

Nesse projeto, os barramentos PIO servem como a ponte de comunicação entre o processador HPS (ARM) e o coprocessador FPGA, permitindo que o código Assembly realize operações diretas sobre o hardware customizado via mapeamento de memória. 

Cada função em Assembly acessa registradores PIO específicos que foram cuidadosamente definidos em Verilog, escrevendo ou lendo comandos, dados e flags para executar ações, verificar resultados ou controlar estados internos da FPGA. Essa arquitetura, baseada em leitura e escrita sequencial de offsets de memória correspondentes aos registradores, permite que o software de alto nível desencadeie e sincronize operações especializadas. Essa seção vai exibir elaborar mais afundo sobre os Barramentos PIO.

 | Sinal |	Direção	Função |	Largura |
 | --- | --- | --- |
| instruct |	Entrada	Palavra de comando (ISA, endereço, dado) |	32 |
| enable |	Entrada	Pulso de ativação do coprocessador |	1 |
| flags |	Saída	Sinalização de status (done, erro, limites) |	4 |
| data_out |	Saída	Retorno para leitura de dados (LOAD) |	8 |

#### 5.1. Detalhamento dos Sinais de Saída.

Os 4 bits do sinal flags indicam o status da operação:

- DONE: Processamento da instrução concluído.

- ERROR: Instrução incorreta, endereço fora do mapeamento ou dado inválido.

- ZOOM_MIN: Tentativa de zoom abaixo do limite permitido.

- ZOOM_MAX: Tentativa de zoom acima do limite permitido.

- Protocolo de Comunicação: É mandatório que o sinal enable seja desativado após cada operação para garantir a sincronização entre software (HPS) e hardware (FPGA).

---

### 6. Análise de resultados.

Essa seção vai detalhar erros, desafios e resultados do projeto.

#### 6.1 Resumo do Produto Final


