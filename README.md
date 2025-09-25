# Coprocessador de Zoom Digital com FPGA

**Universidade Estadual de Feira de Santana (UEFS)**

**Disciplina:** Sistemas Digitais (TEC499) - 2025.2

**Equipe:** Luis Felipe Carneiro Pimentel e Walace de Jesus Venas


## Descrição do Projeto

Para a elaboração do projeto, foi utilizado o kit de desenvolvimento DE1-SoC com o processador Cyclone V, permitindo a leitura e escrita de dados diretamente na memória RAM do dispositivo, o ambiente de desenvolvimento utilizado foi o Quartus Lite na versão 23.1 e para linguagem de descrição de hardware foi lidado com Verilog. O objetivo do problema é projetar um módulo embarcado de redimensionamento de imagens para sistemas de vigilância e exibição em tempo real, o hardware deve aplicar o efeito de zoom-in (Ampliação) e zoom-out (Redução) simulando um comportamento básico de interpolação.


<div align="center">
  <img src="Imagens/de1soc.png"><br>
  <strong>Imagem do Site da Altera</strong><br><br>
</div>

Sumário
=================
  * [1. Levantamento de Requisitos](#1-levantamento-de-requisitos)
  * [2. Softwares Utilizados](#2-softwares-utilizados)
  * [3. Hardware Usado nos Testes](#3-hardware-usado-nos-testes)
  * [4. Instalação e Configuração](#4-instalacão-e-configuração)
  * [5. Testes de Funcionamento](#5-testes-de-funcionamento)
  * [6. Análise dos Resultados](#6-análise-dos-resultados)

### 1. Levantamento de Requisitos

#### 1.1. Requisitos Funcionais
- **RF01:** O sistema deve implementar quatro algoritmos distintos de redimensionamento de imagem.
- **RF02:** Dois algoritmos devem ser para ampliação (Zoom In): *Vizinho Mais Próximo* e *Replicação de Pixel*.
- **RF03:** Dois algoritmos devem ser para redução (Zoom Out): *Decimação* e *Média de Blocos*.
- **RF04:** Todas as operações de zoom devem ser aplicadas em passos de 2X.
- **RF05:** A seleção do algoritmo deve ser feita através de chaves físicas (SW) na placa.
- **RF06:** O controle do nível de zoom (ampliar, reduzir, voltar ao estado anterior) deve ser feito através de botões físicos (KEY).
- **RF07:** A imagem original deve ser exibida na tela assim que o sistema é ligado.
- **RF08:** A imagem processada deve ser exibida numa saída de vídeo VGA padrão (640x480).
- **RF09:** O sistema deve fornecer feedback visual ao utilizador através dos displays de 7 segmentos.
- **RF10:** O sistema deve implementar validações para impedir operações inválidas.

#### 1.2. Requisitos Não-Funcionais
- **RNF01:** O projeto deve ser desenvolvido inteiramente em linguagem **Verilog (2001)**.
- **RNF02:** A implementação deve utilizar apenas os recursos de hardware disponíveis na placa **DE1-SoC**.
- **RNF03:** O código deve ser modular, bem organizado e detalhadamente comentado.


### 2. Softwares Utilizados
- **IDE de Desenvolvimento:** *Intel Quartus Prime Lite Edition (23.1std.0)*
- **Simulador:** *ModelSim - Intel FPGA Edition (2020.1)*
- **Linguagem HDL:** *Verilog-2001*
- **Ferramenta de Conversão:** *Compilador C (MinGW/GCC 6.3.0)*
- **Bibliotecas em C:** *stb_image.h* e *stb_image_resize.h*


### 3. Hardware Usado nos Testes
- **Placa de Desenvolvimento:** Terasic DE1-SoC
- **FPGA:** Intel Cyclone V SE 5CSEMA5F31C6N
- **Memória da Imagem Original:** ROM (19.200 palavras x 8 bits)
- **Memória de Vídeo (Frame Buffer):** RAM de dupla porta (307.200 palavras x 8 bits)
- **Monitor:** Philips VGA (640x480 @ 60Hz)

---

### 4. Instalação e Configuração

#### 4.1. Conversão de Imagem
Compilar ferramenta de conversão gcc converter.c -o converter -lm

Executar conversão ./converter

#### 4.2. Passos para Compilação no Intel Quartus Prime

#### Abrir o Projeto
Abra o ficheiro `Coprocessador.qpf` no **Intel Quartus Prime**.



#### Gerar os IPs de Memória
1. Use a ferramenta **IP Catalog** para gerar os componentes de memória:
   - **ImgRom.qip** → configurado como **ROM: 1-PORT** e inicializado com o ficheiro `.mif` gerado na conversão de imagem.
   - **VdRam.qip** → configurada como **RAM: 2-PORT** com **307.200 palavras de 8 bits**.

> É crucial configurar cada IP corretamente para evitar erros de compilação.



#### Atribuição de Pinos (Pin Assignment)
1. Abra o **Pin Planner**: `Assignments > Pin Planner`.
2. Atribua as portas do módulo `Coprocessador` aos **pinos físicos** da placa **DE1-SoC**, conforme a documentação da placa.



#### Compilação do Projeto
- No menu, selecione **Processing > Start Compilation**.
- Aguarde a síntese, mapeamento, fitting e geração do bitstream.



#### Programação da FPGA
1. Após a compilação bem-sucedida, abra a ferramenta **Programmer**.
2. Carregue o ficheiro `.sof` localizado na pasta `output_files/`.
3. Clique em **Start** para programar a FPGA.

#### Uso da placa programada.
1. Ligar a DE1-SOC pelo botão de _Power_.
2. Esperar o _Display_ de sete segmentos exibir uma mensagem de **"SELECT AN ALGORITHM"** ou esperar a imagem ser exibida no monitor.
3. Selecionar um algoritmo de redimensionamento pelos os _Switches_ da placa. (Do SW[9] até o SW[6], à seleção fonrece os algoritmos _Nearest Neighbor_, _Pixel Replication_, _Decimation_ e _Block Averaging_ respectivamente.
4. Fazer uso dos botões KEY[2] e KEY[3] para aplicar o redimensionamento da imagem. Vale ressaltar que, KEY[2] é responsável em aplicar _zoom-out_ enquanto o KEY[3] aplica o _zoom-in_.
5. Caso a imagem esteja distorcida ou o usuário queira voltar à imagem original, apertar o botão KEY[0] para reiniciar o sistema e voltar para a imagem original.

<div align="center">
  <img src="Imagens/DE1SOC guia.jpg"><br>
  <strong>Componentes necessários para a utilização do projeto.</strong><br><br>
</div>

---


### 5. Testes de Funcionamento

#### 5.1. Mapeamento de Controles

| Função | Componente | Descrição |
|---|---|---|
| Reset Geral | KEY[0] | Reinicia o sistema |
| Voltar Zoom | KEY[1] | Reverte para nível anterior |
| Zoom In | KEY[2] | Reduz em 2x |
| Zoom Out | KEY[3] | Amplia em 2x |
| Alg. 1 | SW[9] | Nearest Neighbor |
| Alg. 2 | SW[8] | Pixel Replication |
| Alg. 3 | SW[7] | Decimation |
| Alg. 4 | SW[6] | Block Averaging |

---

#### 5.2. Sequência de Verificação
- **Inicialização:**
  O display de 7 segmentos deve mostrar **"SELECT AN ALGORITHM"**.
  - Mais de uma chave ligada → display mostra **"SELECTION ERROR"**.

- **Operação de Zoom Válida:**
  - Com SW[0] ou SW[1], pressione **KEY[2]** para zoom in (2x → 4x).
  - Pressione **KEY[3]** para reduzir ao nível anterior.

- **Operação de Zoom Inválida:**
  - Com SW[2] ou SW[3], pressionar **KEY[2]** não deve alterar a imagem.
  - Display mostra **"INVALID ZOOM"**.

- **Botão Voltar:**
  Após qualquer operação de zoom, pressione **KEY[1]** para retornar ao nível normal.

---


### 7. Análise dos Resultados

O projeto implementado foi implementado com as seguintes funcionalidades:
- Suporte a 4 algoritmos de redimensionamento.
- Níveis de zoom de **0.25x a 4.0x**.
- Interface robusta com feedback em display de 7 segmentos.
- Disponibilização de uma imagem para realizar redimensionamento.

Porém, determinados erros permaneceram na entrega da etapa 1 do produto:
- Alteração entre algoritmos de zoom causa uma distorção severa à imagem, tornado-se necessário fazer uso do botão de _Reset_ para evitar isso.
- Todos os algoritmos de zoom distorcem a imagem em certo grau, notavelmente no **nível de zoom 0.25** onde a imagem aparenta ter um espaço maior à esquerda.

### 🔧 Desafios e Soluções
- **Memória:** solução com um único módulo `ImageProcessor` acessando uma única ROM.
