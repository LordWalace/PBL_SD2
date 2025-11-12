**Universidade Estadual de Feira de Santana (UEFS)**

**Disciplina:** Sistemas Digitais (TEC499) - 2025.2

**Equipe:** Luis Felipe Carneiro Pimentel e Walace de Jesus Venas

## Sumário
1. [Visão Geral do Sistema](#visão-geral-do-sistema)

---
Coprocessador FPGA para Processamento de Imagens em Tons de Cinza
---

### 1. Visão Geral do Sistema.

Para a elaboração do projeto, foi utilizado o kit de desenvolvimento DE1-SoC com o processador Cyclone V, o ambiente de desenvolvimento utilizado foi o Quartus Lite na versão 23.1 e para linguagem de descrição de hardware foi lidado com Verilog. As linguagens de programação utilizadas foram C (C23) e Assembly para a conexão entre a placa FPGA e o HPS, permitindo com que o programa consiga carregar imagens pelo HPS e modifique elas fazendo uso dos algoritmos de zoom presentes na placa. 

Está é a segunda etapa do projeto, o objetivo da etapa é realizar o desenvolvimento de uma API para um coprocessador dedicada ao processamento de imagens em escala de cinza (8 bits/pixel), utilizando a linguagem Assembly e restringindo-se estritamente aos componentes de hardware disponíveis na placa. Aplicando a ISA (Instruction Set Architecture) do coprocessador, incorporando as operações de processamento previamente controladas por botões e chaves durante a primeira etapa do projeto.

---

### 2. Softwares Utilizados.
- **IDE de Desenvolvimento:** *Intel Quartus Prime Lite Edition (23.1std.0)*
- **Simulador:** *ModelSim - Intel FPGA Edition (2020.1)*
- **Linguagem HDL:** *Verilog-2001*

---

### 3. Hardware Usado nos Testes.
- **Placa de Desenvolvimento:** Terasic DE1-SoC
- **FPGA:** Intel Cyclone V SE 5CSEMA5F31C6N
- **Memória da Imagem Original:** ROM (19.200 palavras x 8 bits)
- **Memória de Vídeo (Frame Buffer):** RAM de dupla porta (307.200 palavras x 8 bits)
- **Monitor:** Philips VGA (640x480 @ 60Hz)

---


### 3. Arquitetura do Sistema

A arquitetura se baseia em uma divisão clara entre software e hardware para isolar o processamento de pixels e as operações de deslocamento/zoom. A comunicação entre o HPS e o Coprocessador é realizada através de Barramentos PIO (Parallel Input/Output).

#### 3.1. Blocos Principais.

| Bloco	| Descrição	| Implementação Principal
| Qsys System (soc_system) | Integra o processador ARM (HPS), módulos PIO, e lógicas auxiliares (clocks, reset) | Integração do processador |
| Coprocessador | Lógica dedicada para interpretar a ISA, gerenciar memória de imagem, e executar as operações de zoom. | Contém uma FSM e um datapath dedicado. |
| VGA Output | Interface para exibição das imagens ampliadas em um monitor padrão.	| Módulo da placa DE1-SoC |
| Barramentos PIO | Estruturas para troca de sinais de controle, endereço, dados e flags entre HPS e Coprocessador.	| Mapeado via Qsys. |

#### 3.2. Interação com o Código em C.

O código C rodando no HPS é o controlador mestre. Ele:

- Lê e prepara a imagem.

- Monta comandos na forma da ISA definida (palavras de 32 bits).

- Escreve os comandos nos registradores PIO (instructIn).

- Aciona o pulso de ativação (enableIn).

- Aguarda pelas flags de resposta (flagsOut) e lê o resultado (data_out).

---

### 4. Funcionalidades e ISA (Instruction Set Architecture).

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

Sinal	Direção	Função	Largura
instructIn	Entrada	Palavra de comando (ISA, endereço, dado)	32
enableIn	Entrada	Pulso de ativação do coprocessador	1
flagsOut	Saída	Sinalização de status (done, erro, limites)	4
data_out	Saída	Retorno para leitura de dados (LOAD)	8

#### 5.1. Detalhamento dos Sinais de Saída.

Os 4 bits do sinal flagsOut indicam o status da operação:

- DONE: Processamento da instrução concluído.

- ERROR: Instrução incorreta, endereço fora do mapeamento ou dado inválido.

- ZOOM_MIN: Tentativa de zoom abaixo do limite permitido.

- ZOOM_MAX: Tentativa de zoom acima do limite permitido.

- Protocolo de Comunicação: É mandatório que o sinal enableIn seja desativado após cada operação para garantir a sincronização entre software (HPS) e hardware (FPGA).

---

### 6. Estrutura de Pastas e Arquivos.

O código fonte de hardware e a estrutura de integração estão localizados na pasta FPGA/:

- ghrd_top.v: Módulo superior de integração, interliga o sistema Qsys e o coprocessador principal.

- main.v: Contém a implementação do coprocessador, incluindo o interpretador da ISA, FSM de controle, acesso à memória e o algoritmo de zoom.

- soc_system.qsys: Projeto do sistema Qsys, definindo a interconexão (barramentos, PIOs, clocks) entre o HPS e a lógica FPGA.

- Outros Arquivos: Utilitários e componentes auxiliares (reset, detectores de borda, scripts de simulação).

---

### 7. Análise de resultados.

Status (Flag Ativa)	Causa Comum	Ação Recomendada
ERROR	Instrução desconhecida; Endereço fora do mapeamento; Dado inválido (STORE).	Verifique a codificação do OpCode e os limites de endereço.
ZOOM_MIN/MAX	Fator de zoom solicitado excede os limites estabelecidos pelo hardware.	Ajuste o fator de zoom dentro dos parâmetros válidos.
Sem Resposta em DATA_OUT	enableIn não foi acionado ou o protocolo de handshake falhou.	Certifique-se de que o enableIn é setado e desativado corretamente em cada ciclo.
