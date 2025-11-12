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
Este projeto se baseia no desenvolvimento de uma API (Application Programming Interface) feita em **Assembly** para um coprocessador customizado pela equipe, esse que vai ser destinado ao processamento de imagens em escala de cinza. A solução deve ser executada em um hardware embarcado utilizando um Hard Processor System (HPS) ARM como processador principal para comunicação e gerenciamento. As imagens fornecidas pelo usuário devem ser recebidas primeiramente pelo programa e então passadas para o processador para a devida aplicação dos algortimos de zoom fornecidos pelo sistema, elas devem estar em uma resolução especifica e devem estar na escala cinza.

