#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "Coprocessador_Z.h"

#define IMAGE_WIDTH  160
#define IMAGE_HEIGHT 120
#define IMAGE_SIZE   (IMAGE_WIDTH * IMAGE_HEIGHT)
#define MAX_IMAGES   100

char nomes_imagens[MAX_IMAGES][64] = {
    "Arcade"
};
unsigned char imagens[MAX_IMAGES][IMAGE_SIZE];
int num_imagens = 1;

const char* caminhos_bin[MAX_IMAGES] = {
    "imagens/Arcade.bin"
};

const char* algoritmos[] = {
    "Nearest Neighbor",
    "Pixel Replication",
    "Decimation",
    "Block Averaging"
};

void flush_stdin() { int c; while ((c = getchar()) != '\n' && c != EOF); }

unsigned char rgb_to_gray(unsigned char r, unsigned char g, unsigned char b) {
    return (unsigned char)(0.299*r + 0.587*g + 0.114*b);
}

int carregar_imagem_para_160x120(const char* filename, unsigned char* out_buffer) {
    int iw, ih, comp;
    unsigned char *input_img = stbi_load(filename, &iw, &ih, &comp, 3);
    if (!input_img) {
        printf("Erro ao carregar %s\n", filename);
        return 0;
    }
    for (int y = 0; y < IMAGE_HEIGHT; y++) {
        for (int x = 0; x < IMAGE_WIDTH; x++) {
            int src_x = (x * iw) / IMAGE_WIDTH;
            int src_y = (y * ih) / IMAGE_HEIGHT;
            int idx_src = (src_y * iw + src_x) * 3;
            unsigned char r = input_img[idx_src + 0];
            unsigned char g = input_img[idx_src + 1];
            unsigned char b = input_img[idx_src + 2];
            out_buffer[y * IMAGE_WIDTH + x] = rgb_to_gray(r, g, b);
        }
    }
    stbi_image_free(input_img);
    return 1;
}

// NOVO: Carrega todos os .bin para buffer imagens[...]
void carregar_imagens_bin() {
    for (int i = 0; i < num_imagens; ++i) {
        FILE *f = fopen(caminhos_bin[i], "rb");
        if (f) {
            size_t lidos = fread(imagens[i], 1, IMAGE_SIZE, f);
            fclose(f);
            if (lidos != IMAGE_SIZE) {
                printf("Aviso: Imagem '%s' lida parcialmente (%zu bytes).\n", caminhos_bin[i], lidos);
            } else {
                printf("Imagem '%s' carregada com sucesso.\n", caminhos_bin[i]);
            }
        } else {
            printf("Erro ao abrir o arquivo: %s\n", caminhos_bin[i]);
        }
    }
}

void envia_imagem_para_fpga(const unsigned char* buffer) {
    for (unsigned i = 0; i < IMAGE_SIZE; ++i)
        escrever_pixel(i, buffer[i]);
}

int main() {
    int zoom = 4, alg = 0, img = 0;
    iniciarCoprocessor();
    resetCoprocessor();

    // Passos 1 e 2: Carrega Arcade.bin no buffer antes do menu
    carregar_imagens_bin();
// escrever_pixel
MENU_IMG:
    while (1) {
        printf("\n==== COPROCESSADOR DE IMAGEM ====\n");
        for (int i = 0; i < num_imagens; ++i)
        printf("%2d - %s\n", i, nomes_imagens[i]);
        printf("n - Adicionar nova imagem (BMP/JPG/PNG)\n");
        printf("q - Sair\n");
        printf("Digite o número da imagem, 'n' para nova ou 'q' para sair: ");

        char opt[32];
        if (!fgets(opt, sizeof(opt), stdin)) break;

        if (tolower(opt[0]) == 'q') {
            encerrarCoprocessor();
            printf("Programa finalizado.\n");
            return 0;
        }
        if (tolower(opt[0]) == 'n') {
            if (num_imagens >= MAX_IMAGES) {
                printf("Limite de imagens atingido.\n");
                continue;
            }
            printf("Nome do arquivo de imagem (BMP/PNG/JPG): ");
            char nome_arquivo[128];
            if (!fgets(nome_arquivo, 127, stdin)) break;
            nome_arquivo[strcspn(nome_arquivo, "\n")] = 0;

            printf("Nome para identificar no menu: ");
            if (!fgets(nomes_imagens[num_imagens], 63, stdin)) break;
            nomes_imagens[num_imagens][strcspn(nomes_imagens[num_imagens], "\n")] = 0;

            if (!carregar_imagem_para_160x120(nome_arquivo, imagens[num_imagens])) {
                printf("Não foi possível converter a imagem. Verifique e tente novamente.\n");
                continue;
            }
            printf("Imagem '%s' convertida e adicionada!\n", nomes_imagens[num_imagens]);
            ++num_imagens;
            continue;
        }

        img = atoi(opt);
        if (img < 0 || img >= num_imagens) {
            printf("Opção inválida!\n");
            continue;
        }

        printf("Carregando imagem '%s' (%d)...\n", nomes_imagens[img], img);
        envia_imagem_para_fpga(imagens[img]);
        printf("Imagem enviada para a FPGA! Você pode ver a imagem ORIGINAL na VGA agora.\n");
        break; // segue para menu de zoom
    }

    configurar_algoritmo_zoom(alg, zoom);
    start_processing();
    aguardar_processamento();

    while (1) {
        printf("\n[+] Zoom In |  [-] Zoom Out | [M] Mudar Imagem | [Q] Sair\n");
        printf("Selecione: ");
        int opt = getchar(); flush_stdin();

        if (opt == 'q' || opt == 'Q') break;
        if (opt == 'm' || opt == 'M') { goto MENU_IMG; }

        if (opt == '+') {
            printf("\nAlgoritmos para Zoom IN (aproximar):\n");
            printf("1. %s\n", algoritmos[0]);
            printf("2. %s\n", algoritmos[1]);
            printf("Escolha [1-2]: ");
            int c = getchar(); flush_stdin();
            if (c == '1' || c == '2') {
                alg = c - '1';
                if (zoom > 1) zoom /= 2;
                printf("Algoritmo: %s, Zoom: %dx\n",algoritmos[alg], zoom);
                configurar_algoritmo_zoom(alg, zoom);
                start_processing();
                aguardar_processamento();
            } else printf("Opcao invalida.\n");
        } else if (opt == '-') {
            printf("\nAlgoritmos para Zoom OUT (afastar):\n");
            printf("3. %s\n", algoritmos[2]);
            printf("4. %s\n", algoritmos[3]);
            printf("Escolha [3-4]: ");
            int c = getchar(); flush_stdin();
            if (c == '3' || c == '4') {
                alg = c - '1';
                if (zoom < 8) zoom *= 2;
                printf("Algoritmo: %s, Zoom: %dx\n", algoritmos[alg], zoom);
                configurar_algoritmo_zoom(alg, zoom);
                start_processing();
                aguardar_processamento();
            } else printf("Opcao invalida.\n");
        } else
            printf("Entrada invalida. Use +, -, M, Q.\n");
    }

    encerrarCoprocessor();
    printf("Programa finalizado.\n");
    return 0;
}