# Sistema de Zoom Embarcado - DE1-SoC (Cyclone V)

**Disciplina:** Sistemas Digitais (TEC499) - 2025.2, UEFS

**Equipe:** Luis Felipe Carneiro Pimentel e Walace de Jesus Venas

## Descrição e Objetivo do Projeto

Este projeto consiste no desenvolvimento de um **módulo de redimensionamento de imagens (zoom)** embarcado na placa **DE1-SoC (FPGA Cyclone V)**. O hardware foi projetado para simular um sistema básico de vigilância e exibição em tempo real, aplicando algoritmos de ampliação (Zoom In) e redução (Zoom Out) em passos de 2X. Todo o controle e *feedback* ao usuário são realizados através dos componentes físicos da placa e do proprio programa feito em C.

---

## Navegação e Interfaces e Guia de Usuário

O sistema é operado através de um **menu de texto interativo**.

### 1. Menu Principal

Ao iniciar o programa, este menu será exibido. Digite o número da opção desejada e pressione **ENTER**.

| Opção | Ação | Observação |
| :--- | :--- | :--- |
| **[1] Carregar Imagem** | Vai para o menu de seleção de imagens. | Caso nenhuma imagem seja selecionada uma imagem "padrão" já é carregada. |
| **[2] Aplicar Zoom** | Vai para o menu de algoritmos de zoom.| Só é possível com uma imagem carregada. |
| **[3] Reset do Sistema** | Limpa o estado atual do coprocessador FPGA. | Util para retornar a imagem para seu estado "original" (Sem zooms) |
| **[4] Status** | Faz o terminal exibir as propriedades atuais do sistema. | Exibe flags e informações sobre o estado atual do sistema e dimensões suportadas. |
| **[0] Sair** | Encerra o programa. | |

<div align="center">
  <img src="https://i.postimg.cc/wBKD3kQg/Menu.png"><br>
  <strong>Imagem do menu principal</strong><br><br>
</div>

### 2. Menu de Seleção de Imagens

Após escolher a opção **[1]**, uma lista de arquivos BMP disponíveis na pasta será exibida.

* Digite o número correspondente à imagem que deseja carregar (Ex: **1** para `Xadrez.bmp`).
* Pressione **ENTER**.
* A imagem selecionada será carregada e enviada para o coprocessador FPGA.


<div align="center">
  <img src="https://i.postimg.cc/6QdnZGMX/Imagem-Select.png"><br>
  <strong>Imagem do menu principal</strong><br><br>
</div>

### 3. Menu de Zoom

Após carregar uma imagem, a opção **[2]** levará a este menu, que lista os algoritmos disponíveis:

| Opção | Algoritmo | Fator de Escala (Exemplos) | Efeito |
| :--- | :--- | :--- | :--- |
| **[1]** | **Vizinho Mais Próximo** | 2x, 4x, 8x | Zoom In (Aumentar) |
| **[2]** | **Replicação de Pixel** | 2x, 4x, 8x | Zoom In (Aumentar) |
| **[3]** | **Decimação** | 0.5x, 0.25x, 0.125x | Zoom Out (Diminuir) |
| **[4]** | **Média de Blocos** | 0.5x, 0.25x, 0.125x | Zoom Out (Diminuir) |
| **[0]** | **Voltar** | Retorna ao Menu Principal. |

* Selecione o número do algoritmo e pressione **ENTER**.
* O sistema irá processar a imagem no FPGA e exibir o resultado no monitor VGA (se conectado).
* Um passo de zoom é aplicado a cada execução (ex: se o fator é 1x, um zoom in resultará em 2x; se for 2x, resultará em 4x, e assim por diante).



<div align="center">
  <img src="https://i.postimg.cc/yNFcRSL9/Imagem-Normal.jpg"><br>
  <strong>Imagem no seu estado padrão.</strong><br><br>
</div>

<div align="center">
  <img src="https://i.postimg.cc/PqmYD8S5/Aplicar-Zoom-In.png"><br>
  <strong>Imagem do menu após selecionar um algoritmo Zoom-In 8x.</strong><br><br>
</div>

<div align="center">
  <img src="https://i.postimg.cc/9fGZ9qLf/Imagem-Zoom-In.jpg"><br>
  <strong>Imagem com um algoritmo de Zoom-In 8x aplicado.</strong><br><br>
</div>

<div align="center">
  <img src="https://i.postimg.cc/yNFcRSLV/Aplicar-Zoom-Out.png"><br>
  <strong>Imagem do menu após selecionar um algoritmo Zoom-Out 0.125x.</strong><br><br>
</div>

<div align="center">
  <img src="https://i.postimg.cc/cJQw38XV/Imagem-Zoom-Out.jpg"><br>
  <strong>Imagem com um algoritmo de Zoom-Out 0.125x aplicado.</strong><br><br>
</div>

---

## Erros Comuns e Mensagens de Alerta

O sistema foi desenhado para reportar problemas de forma clara:

| Categoria | Mensagem de Erro | Ocorrência Comum | Ação Recomendada |
| :--- | :--- | :--- | :--- |
| **Arquivos** | `❌ Erro ao abrir 'nome_do_arquivo'` | O arquivo BMP selecionado não está na pasta correta. | Verifique se a imagem está no mesmo diretório do programa e tente novamente. |
| | `❌ Arquivo não é BMP válido` | O arquivo selecionado não segue o formato BMP ou está corrompido. | Use apenas arquivos BMP válidos. |
| | `❌ Dimensão incorreta: DxH (esperado 320x240)` | A imagem não tem a resolução de **320x240 pixels** esperada. | Utilize apenas imagens BMP com a dimensão correta. |
| | `❌ Formato X bits não suportado` | O formato de cor da imagem (8, 24 ou 32 bits) é diferente do suportado. | Utilize imagens BMP com 8, 24 ou 32 bits por pixel. |
| **Sistema** | `❌ Erro ao enviar imagem para FPGA` | Falha de comunicação ao transferir os dados da imagem para o hardware. | Tente a operação novamente e, se o problema persistir, verifique a conexão do hardware. |
| | `❌ Hardware reportou erro!` | O coprocessador FPGA indicou uma falha interna. | Tente a operação novamente e/ou utilize a opção **[3] Reset do Sistema**. |
| | `❌ Operação não concluiu no tempo esperado TIMEOUT!` | O algoritmo de zoom não terminou no tempo limite (5 segundos). | Aumentar o tempo de espera pode ser necessário para operações complexas. |
| **Zoom** | `⚠️ Zoom máximo atingido (8x)` | Tentativa de aplicar zoom in (aumentar) após atingir o limite de 8x. | O zoom in só pode ser aplicado até 8x (2x -> 4x -> 8x). |
| | `⚠️ Zoom mínimo atingido (0.125x)` | Tentativa de aplicar zoom out (diminuir) após atingir o limite de 0.125x. | O zoom out só pode ser aplicado até 0.125x (0.5x -> 0.25x -> 0.125x). |

---
