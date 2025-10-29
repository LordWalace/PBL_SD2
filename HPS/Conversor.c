#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include <stdio.h>
#include <stdlib.h>

#define OUT_WIDTH  160
#define OUT_HEIGHT 120

// Função para converter RGB para Gray
unsigned char rgb_to_gray(unsigned char r, unsigned char g, unsigned char b) {
    return (unsigned char)(0.299*r + 0.587*g + 0.114*b);
}

int main(int argc, char **argv) {
    if (argc < 3) {
        printf("Uso: %s <input_img> <output_bin>\n", argv[0]);
        return 1;
    }

    int w, h, comp;
    unsigned char* input_img = stbi_load(argv[1], &w, &h, &comp, 3);
    if (!input_img) {
        printf("Erro ao carregar imagem %s\n", argv[1]);
        return 1;
    }
    // Cria buffer final (grayscale, 1 byte por pixel)
    unsigned char output_img[OUT_WIDTH * OUT_HEIGHT];

    // Redimensiona com amostragem simples, conversão para cinza
    for (int y = 0; y < OUT_HEIGHT; y++) {
        for (int x = 0; x < OUT_WIDTH; x++) {
            int src_x = (x * w) / OUT_WIDTH;
            int src_y = (y * h) / OUT_HEIGHT;
            int idx_src = (src_y * w + src_x) * 3;
            unsigned char r = input_img[idx_src + 0];
            unsigned char g = input_img[idx_src + 1];
            unsigned char b = input_img[idx_src + 2];

            output_img[y * OUT_WIDTH + x] = rgb_to_gray(r, g, b);
        }
    }
    stbi_image_free(input_img);

    // Salva em arquivo binário plano
    FILE *f = fopen(argv[2], "wb");
    if (!f) {
        printf("Erro ao criar arquivo de saída %s\n", argv[2]);
        return 1;
    }
    fwrite(output_img, 1, OUT_WIDTH * OUT_HEIGHT, f);
    fclose(f);

    printf("Imagem convertida e salva em %s\n", argv[2]);
    return 0;
}