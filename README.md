<!--
# 📟 Coprocessador de Zoom Digital com FPGA

**Universidade Estadual de Feira de Santana (UEFS)**  
**Disciplina:** Sistemas Digitais (TEC499) - 2025.2  
**Equipe:** Luis Felipe Carneiro Pimentel e Walace de Jesus Venas  

---

## 1. Levantamento de Requisitos

### 1.1. Requisitos Funcionais
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

### 1.2. Requisitos Não-Funcionais
- **RNF01:** O projeto deve ser desenvolvido inteiramente em linguagem **Verilog (2001)**.  
- **RNF02:** A implementação deve utilizar apenas os recursos de hardware disponíveis na placa **DE1-SoC**.  
- **RNF03:** O código deve ser modular, bem organizado e detalhadamente comentado.  

---

## 2. Softwares Utilizados
- **IDE de Desenvolvimento:** *Intel Quartus Prime Lite Edition (23.1std.0)*  
- **Simulador:** *ModelSim - Intel FPGA Edition (2020.1)*  
- **Linguagem HDL:** *Verilog-2001*  
- **Ferramenta de Conversão:** *Compilador C (MinGW/GCC 6.3.0)*  
- **Bibliotecas em C:** *stb_image.h* e *stb_image_resize.h*  

---

## 3. Hardware Usado nos Testes
- **Placa de Desenvolvimento:** Terasic DE1-SoC  
- **FPGA:** Intel Cyclone V SE 5CSEMA5F31C6N  
- **Memória da Imagem Original:** ROM (19.200 palavras x 8 bits)  
- **Memória de Vídeo (Frame Buffer):** RAM de dupla porta (307.200 palavras x 8 bits)  
- **Monitor:** Philips VGA (640x480 @ 60Hz)  

---

## 4. Instalação e Configuração

### 4.1. Conversão de Imagem

#### Compilar ferramenta de conversão gcc converter.c -o converter -lm

#### Executar conversão ./converter

#### Compilação no Quartus

### 4.2. Passos para Compilação no Intel Quartus Prime

### 🔹 Abrir o Projeto
Abra o ficheiro `Coprocessador.qpf` no **Intel Quartus Prime**.

---

### 🔹 Gerar os IPs de Memória
1. Use a ferramenta **IP Catalog** para gerar os componentes de memória:  
   - **ImgRom.qip** → configurado como **ROM: 1-PORT** e inicializado com o ficheiro `.mif` gerado na conversão de imagem.  
   - **VdRam.qip** → configurada como **RAM: 2-PORT** com **307.200 palavras de 8 bits**.  

> ⚠️ É crucial configurar cada IP corretamente para evitar erros de compilação.  

---

### 🔹 Atribuição de Pinos (Pin Assignment)
1. Abra o **Pin Planner**: `Assignments > Pin Planner`.  
2. Atribua as portas do módulo `Coprocessador` aos **pinos físicos** da placa **DE1-SoC**, conforme a documentação da placa.  

---

### 🔹 Compilação do Projeto
- No menu, selecione **Processing > Start Compilation**.  
- Aguarde a síntese, mapeamento, fitting e geração do bitstream.  

---

### 🔹 Programação da FPGA
1. Após a compilação bem-sucedida, abra a ferramenta **Programmer**.  
2. Carregue o ficheiro `.sof` localizado na pasta `output_files/`.  
3. Clique em **Start** para programar a FPGA.  

---

## 🧪 5. Testes de Funcionamento

### 5.1. Mapeamento de Controles

| Função         | Componente | Descrição |
|----------------|------------|-----------|
| Reset Geral    | KEY[0]     | Reinicia o sistema |
| Voltar Zoom    | KEY[1]     | Reverte para nível anterior |
| Zoom In        | KEY[2]     | Reduz em 2x |
| Zoom Out       | KEY[3]     | Amplia em 2x |
| Alg. 1         | SW[0]      | Nearest Neighbor |
| Alg. 2         | SW[1]      | Pixel Replication |
| Alg. 3         | SW[2]      | Decimation |
| Alg. 4         | SW[3]      | Block Averaging |

---

### 5.2. Sequência de Verificação
- **Inicialização:**  
  Ao ligar a placa, a imagem original (160x120) deve aparecer centralizada no monitor.  
  O display de 7 segmentos deve mostrar **"SELECT AN ALGORITHM"**.  

- **Seleção de Algoritmo:**  
  - Apenas uma chave ligada → mostra o algoritmo selecionado.  
  - Mais de uma chave ligada → display mostra **"SELECTION ERROR"**.  

- **Operação de Zoom Válida:**  
  - Com SW[0] ou SW[1], pressione **KEY[2]** para zoom in (2x → 4x).  
  - Pressione **KEY[3]** para reduzir ao nível anterior.  

- **Operação de Zoom Inválida:**  
  - Com SW[2] ou SW[3], pressionar **KEY[2]** não deve alterar a imagem.  
  - Display mostra **"INVALID ZOOM"**.  

- **Botão Voltar:**  
  Após qualquer operação de zoom, pressione **KEY[1]** para retornar ao nível anterior.  
  
---

## 📊 6. Análise dos Resultados

✅ Projeto implementado com sucesso:  
- Suporte a 4 algoritmos de redimensionamento.  
- Níveis de zoom de **0.25x a 4.0x**.  
- Interface robusta com feedback em display de 7 segmentos.  

### 🔧 Desafios e Soluções
- **Memória:** solução com um único módulo `ImageProcessor` acessando uma única ROM.    
-->
