# 🔎 Sistema de Zoom Embarcado - DE1-SoC (Cyclone V)

**Disciplina:** Sistemas Digitais (TEC499) - 2025.2, UEFS

**Equipe:** Luis Felipe Carneiro Pimentel e Walace de Jesus Venas

## 🎯 Descrição e Objetivo do Projeto

Este projeto consiste no desenvolvimento de um **módulo de redimensionamento de imagens (zoom)** embarcado na placa **DE1-SoC (FPGA Cyclone V)**. O hardware foi projetado para simular um sistema básico de vigilância e exibição em tempo real, aplicando algoritmos de ampliação (Zoom In) e redução (Zoom Out) em passos de 2X. Todo o controle e *feedback* ao usuário são realizados através dos componentes físicos da placa e do proprio programa feito em C.

---

## 💻 2. Detalhes de Implementação

### 2.1. Requisitos Funcionais e Algoritmos
  
O sistema implementa quatro algoritmos distintos, controlados pelas **chaves SW[0] a SW[3]**:

| Chave | Função | Algoritmo | Tipo de Zoom | Nível de Zoom |
| :---: | :--- | :--- | :--- | :--- |
| **SW[0]** | Ampliação | Vizinho Mais Próximo | Zoom In | 1x → 2x → 4x |
| **SW[1]** | Ampliação | Replicação de Pixel | Zoom In | 1x → 2x → 4x |
| **SW[2]** | Redução | Decimação | Zoom Out | 1x → 0.5x → 0.25x |
| **SW[3]** | Redução | Média de Blocos | Zoom Out | 1x → 0.5x → 0.25x |

### 2.2. Hardware e Software

| Categoria | Componente/Software | Especificação |
| :--- | :--- | :--- |
| **Placa** | Terasic DE1-SoC | FPGA Intel Cyclone V SE 5CSEMA5F31C6N |
| **Linguagem** | Verilog HDL | Verilog-2001 (Código modular e comentado) |
| **IDE** | Intel Quartus Prime Lite Edition | Versão 23.1std.0 |
| **Simulador** | ModelSim - Intel FPGA Edition | Versão 2020.1 |
| **Exibição** | Saída VGA | Resolução 640x480 @ 60Hz |

### 2.3. Mapeamento de Controles Físicos

| Função | Componente | Descrição |
| :--- | :--- | :--- |
| **Reset Geral** | **KEY[0]** | Reinicia o sistema e retorna a imagem ao estado padrão (1x). |
| **Zoom Out** | **KEY[2]** | Aplica o zoom do algoritmo selecionado (ex.: 1x → 2x). |
| **Zoom In** | **KEY[3]** | Aplica o zoom reverso do algoritmo selecionado (ex.: 2x → 1x). |
| Voltar Zoom | KEY[1] | *Lógica presente no código, mas pino não atribuído no projeto final.* |
| Seleção Alg. | SW[0]-SW[3] | Seleção do algoritmo de redimensionamento. |

---

## 🛠️ 3. Guia de Instalação e Uso

### 3.1. Compilação e Programação no Quartus

1.  **Abrir o Projeto:** Abra o ficheiro `Coprocessador.qpf` no **Intel Quartus Prime**. Certifique-se de que o *hardware* selecionado é o **DE-SOC**.
2.  **Geração de IPs de Memória:** Caso esteja configurando o projeto pela primeira vez, utilize o **IP Catalog** para gerar:
    * **ImgRom.qip:** ROM: 1-PORT (19200x8 bits), inicializada com o ficheiro `.mif` da imagem.
    * **VdRam.qip:** RAM: 2-PORT (307.200x8 bits).
    > **NOTA:** Se todos os arquivos do projeto foram baixados, esta etapa e a atribuição de pinos não são necessárias.
3.  **Compilação:** No menu, selecione **Processing > Start Compilation**. Aguarde a mensagem **"Successful"** na barra de progresso.
4.  **Programação:** Abra a ferramenta **Programmer**, carregue o ficheiro **`.sof`** (localizado em `output_files/`) e clique em **Start** para programar a FPGA.

### 3.2. Uso da Placa Programada 🎮

1.  **Conexões:** Conecte os cabos de **alimentação**, **VGA** (para monitor) e **USB** (para programação) na DE1-SoC.
2.  **Ligar:** Ligue a placa pelo botão de **Power**. A imagem inicial (1x) deve ser exibida no monitor.
3.  **Seleção:** Use as chaves **SW[0] a SW[3]** para selecionar **apenas um** algoritmo:
    * **Seleção Válida:** Display de 7 segmentos deve mostrar **"SELECT AN ALGORITHM"**.
    * **Erro de Seleção:** Se mais de uma chave estiver ligada, o display mostrará **"SELECTION ERROR"**.
4.  **Operação de Zoom:**
    * Pressione **KEY[2]** para aplicar o **Zoom IN** (se selecionado SW[0] ou SW[1]).
    * Pressione **KEY[3]** para aplicar o **Zoom OUT** (se selecionado SW[2] ou SW[3]).
5.  **Reset:** Pressione **KEY[0]** a qualquer momento para reiniciar o sistema e retornar a imagem ao seu estado original (1x).

---

## ⚠️ 4. Análise e Limitações

### 4.1. Feedback Visual dos Displays (7 Segmentos)

| Mensagem do Display | Significado |
| :--- | :--- |
| **"SELECT AN ALGORITHM"** | Estado inicial, esperando a seleção de um único algoritmo (SW). |
| **"SELECTION ERROR"** | Mais de uma chave de algoritmo (SW[0] - SW[3]) está ligada. |
| **"INVALID ZOOM"** | Tentativa de aplicar Zoom Out (KEY[3]) em um algoritmo de Zoom In (SW[0]/SW[1]), ou vice-versa. |

### 4.2. Limitações e Desafios (Etapa 1)

O projeto final desta etapa apresenta as seguintes limitações de uso, que podem ser abordadas em futuras iterações:

* **Distorção ao Trocar Algoritmos:** A **troca de algoritmo** enquanto a imagem está em um nível de zoom diferente de 1x (padrão) causa **distorção severa**.
    * ***Solução Proposta:*** Recomenda-se apertar **KEY[0] (Reset)** sempre antes de trocar o algoritmo para garantir a imagem padrão (1x). Uma solução futura seria implementar um "reset automático" ao detectar a troca de SW fora do nível 1x.
* **Limitação do Nível de Zoom:** Os algoritmos são limitados a **duas etapas** de ampliação (até 4x) e duas de redução (até 0.25x).
* **Botão KEY[1]:** A funcionalidade de "Voltar Zoom" está implementada no Verilog, mas **o pino físico não foi atribuído** no projeto final, desativando o botão.

| Erro Visível no Monitor | Causa |
| :---: | :--- |
|  | Acionar Zoom Out (KEY[3]) após atingir o zoom máximo (4x) com um algoritmo de Zoom In (SW[0] ou SW[1]) causa distorção. |
|  | Acionar Zoom In (KEY[2]) após atingir o zoom mínimo (0.25x) com um algoritmo de Zoom Out (SW[2] ou SW[3]) causa distorção. |

---

O que mais você gostaria de adicionar ou detalhar neste README?
