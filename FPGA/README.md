**Universidade Estadual de Feira de Santana (UEFS)**

**Disciplina:** Sistemas Digitais (TEC499) - 2025.2

**Equipe:** Luis Felipe Carneiro Pimentel e Walace de Jesus Venas

## Sumário
1. [Visão Geral do Sistema](#visão-geral-do-sistema)

---
Coprocessador FPGA para Processamento de Imagens em Tons de Cinza
---
## Visão Geral do Sistema
Este projeto se baseia no desenvolvimento de uma API (Application Programming Interface) feita em **Assembly** para um coprocessador customizado pela equipe, esse que vai ser destinado ao processamento de imagens em escala de cinza. A solução deve ser executada em um hardware embarcado utilizando um Hard Processor System (HPS) ARM como processador principal para comunicação e gerenciamento. As imagens fornecidas pelo usuário devem ser recebidas primeiramente pelo programa e então passadas para o processador para a devida aplicação dos algortimos de zoom fornecidos pelo sistema, elas devem estar em uma resolução especifica de 320x240 _pixels_ e devem estar na escala cinza.
É claro! Aqui está o conteúdo para o arquivo README.md, formatado em Markdown, com base na descrição do projeto que você forneceu.

2. Objetivo e Aceleração

O foco é a aceleração do tratamento de dados de imagens ao delegar a execução de operações intensivas (como o zoom) ao coprocessador em FPGA.

    HPS (ARM): Responsável por atividades de alto nível, como interface de usuário, gerência de arquivos (recebimento de imagens via Ethernet/SD) e controle geral.

    FPGA (Coprocessador): Atua como acelerador, executando o algoritmo de zoom sob demanda, reduzindo a carga de trabalho do ARM e otimizando o desempenho geral do sistema.

3. Arquitetura do Sistema

A arquitetura se baseia em uma divisão clara entre software e hardware para isolar o processamento de pixels e as operações de deslocamento/zoom. A comunicação entre o HPS e o Coprocessador é realizada através de Barramentos PIO (Parallel Input/Output).

3.1. Blocos Principais

Bloco	Descrição	Implementação Principal
Qsys System (soc_system)	Integração do processador ARM (HPS), módulos PIO, e lógicas auxiliares (clocks, reset).	soc_system.qsys
Coprocessador	Lógica dedicada para interpretar a ISA, gerenciar memória de imagem, e executar as operações de zoom. Contém uma FSM e um datapath dedicado.	main.v
VGA Output	Interface para exibição das imagens ampliadas em um monitor padrão.	Módulo da placa DE1-SoC
Barramentos PIO	Estruturas para troca de sinais de controle, endereço, dados e flags entre HPS e Coprocessador.	Mapeado via Qsys

3.2. Interação com o Código em C

O código C rodando no HPS é o controlador mestre. Ele:

    Lê e prepara a imagem.

    Monta comandos na forma da ISA definida (palavras de 32 bits).

    Escreve os comandos nos registradores PIO (instructIn).

    Aciona o pulso de ativação (enableIn).

    Aguarda pelas flags de resposta (flagsOut) e lê o resultado (data_out).

4. ⚙️ Funcionalidades e ISA (Instruction Set Architecture)

O coprocessador implementa uma ISA enxuta com três classes de instrução, focadas em transferência de dados e execução de zoom:
Classe	Descrição
LOAD	Leitura de dado da memória de imagem.
STORE	Escrita de dado na memória de imagem.
ZOOM	Execução da operação de ampliação/redução sobre uma região.

4.1. Formato da Instrução (Palavra de 32 bits)

Bits	Função
[2:0]	Código da operação (OpCode)
[19:3]	Endereço de memória
[28:21]	Dado de entrada (apenas para STORE)
[31:29]	Reservado

4.2. Algoritmo de Zoom

O algoritmo empregado é o "Nearest Neighbor" (Vizinho Mais Próximo). Ele é ideal para hardware embarcado por sua baixa complexidade e bom desempenho, realizando o zoom através da replicação de pixels conforme um fator definido.

5. Barramentos PIO e Sinais de Comunicação

Sinal	Direção	Função	Largura
instructIn	Entrada	Palavra de comando (ISA, endereço, dado)	32
enableIn	Entrada	Pulso de ativação do coprocessador	1
flagsOut	Saída	Sinalização de status (done, erro, limites)	4
data_out	Saída	Retorno para leitura de dados (LOAD)	8

5.1. Detalhamento dos Sinais de Saída (flagsOut)

Os 4 bits do sinal flagsOut indicam o status da operação:

    DONE: Processamento da instrução concluído.

    ERROR: Instrução incorreta, endereço fora do mapeamento ou dado inválido.

    ZOOM_MIN: Tentativa de zoom abaixo do limite permitido.

    ZOOM_MAX: Tentativa de zoom acima do limite permitido.

    Protocolo de Comunicação: É mandatório que o sinal enableIn seja desativado após cada operação para garantir a sincronização entre software (HPS) e hardware (FPGA).

6. Estrutura de Pastas e Arquivos

O código fonte de hardware e a estrutura de integração estão localizados na pasta FPGA/:

    ghrd_top.v: Módulo superior de integração, interliga o sistema Qsys e o coprocessador principal.

    main.v: Contém a implementação do coprocessador, incluindo o interpretador da ISA, FSM de controle, acesso à memória e o algoritmo de zoom.

    soc_system.qsys: Projeto do sistema Qsys, definindo a interconexão (barramentos, PIOs, clocks) entre o HPS e a lógica FPGA.

    Outros Arquivos: Utilitários e componentes auxiliares (reset, detectores de borda, scripts de simulação).

7. Como Utilizar/Testar o Projeto

7.1. Pré-requisitos

    Software: Quartus Prime (Altera/Intel) compatível com a DE1-SoC.

    Hardware: Placa DE1-SoC com Cyclone V e cabo USB-Blaster.

    Software Host: Ambiente de desenvolvimento e compilação C para ARM Linux.

    Imagem: Imagem de teste em tons de cinza, preparada para transferência ao HPS.

7.2. Etapas de Execução

    Compilação FPGA: Abra o Quartus, compile os arquivos Verilog (FPGA/) e gere o bitstream (.sof).

    Configuração da Placa: Programe a placa DE1-SoC via USB-Blaster com o bitstream gerado.

    Software C: No Linux do HPS, compile e execute o software C de interface. Este software irá:

        Ler a imagem de teste.

        Montar e enviar as instruções (palavras de 32 bits) via PIO (instructIn).

        Gerar o pulso em enableIn.

        Ler o flagsOut para verificar status (DONE, ERROR, etc.) e o data_out para resultados.

    Verificação: A saída do zoom pode ser conferida no monitor via a interface VGA da placa.

8. Erros Comuns e Alertas

Status (Flag Ativa)	Causa Comum	Ação Recomendada
ERROR	Instrução desconhecida; Endereço fora do mapeamento; Dado inválido (STORE).	Verifique a codificação do OpCode e os limites de endereço.
ZOOM_MIN/MAX	Fator de zoom solicitado excede os limites estabelecidos pelo hardware.	Ajuste o fator de zoom dentro dos parâmetros válidos.
Sem Resposta em DATA_OUT	enableIn não foi acionado ou o protocolo de handshake falhou.	Certifique-se de que o enableIn é setado e desativado corretamente em cada ciclo.
