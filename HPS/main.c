#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include "LibCoprocessador.h"

// Estrutura do header BMP
typedef struct {
    uint16_t signature;             
    uint32_t file_size;
    uint32_t reserved;
    uint32_t pixel_offset;          
    uint32_t header_size;           
    int32_t  width;
    int32_t  height;
    uint16_t planes;
    uint16_t bits_per_pixel;
    uint32_t compression;
    uint32_t image_size;
    int32_t  x_pixels_per_meter;
    int32_t  y_pixels_per_meter;
    uint32_t colors_used;
    uint32_t colors_important;
} BMPHeader;

// Carrega BMP e envia para FPGA
int load_bmp_to_fpga(const char *filename) {
    FILE *fp = fopen(filename, "rb");
    if (!fp) {
        printf("ERRO: Não conseguiu abrir '%s'\n", filename);
        return -1;
    }

    BMPHeader header;
    if (fread(&header, 1, 54, fp) != 54) {
        printf("ERRO: Falha ao ler header do BMP\n");
        fclose(fp);
        return -1;
    }

    if (header.signature != 0x4D42) {
        printf("ERRO: Arquivo não é um BMP válido\n");
        fclose(fp);
        return -1;
    }

    printf("INFO: Arquivo BMP encontrado\n");
    printf("  - Dimensões: %dx%d\n", header.width, header.height);
    printf("  - Bits por pixel: %d\n", header.bits_per_pixel);

    if (header.width != IMG_WIDTH || header.height != IMG_HEIGHT) {
        printf("AVISO: Imagem tem dimensões %dx%d, esperado %dx%d\n",
               header.width, header.height, IMG_WIDTH, IMG_HEIGHT);
    }

    fseek(fp, header.pixel_offset, SEEK_SET);

    printf("Carregando imagem para FPGA...\n");
    int pixels_written = 0;
    int errors = 0;

    uint8_t *row_buffer = (uint8_t *)malloc(IMG_WIDTH * 3);
    if (!row_buffer) {
        printf("ERRO: Falha ao alocar buffer\n");
        fclose(fp);
        return -1;
    }

    // BMP armazena de baixo para cima
    for (int row = IMG_HEIGHT - 1; row >= 0; row--) {
        int bytes_read = fread(row_buffer, 1, IMG_WIDTH * 3, fp);
        if (bytes_read < IMG_WIDTH * 3) {
            printf("AVISO: Linha incompleta lida\n");
        }

        for (int col = 0; col < IMG_WIDTH; col++) {
            uint8_t B = row_buffer[col * 3 + 0];
            uint8_t G = row_buffer[col * 3 + 1];
            uint8_t R = row_buffer[col * 3 + 2];

            // Converte RGB para escala de cinza
            uint8_t gray = (uint8_t)((R * 299 + G * 587 + B * 114) / 1000);

            int addr = row * IMG_WIDTH + col;

            int result = write_pixel(addr, gray);

            if (result == 0) {
                pixels_written++;
            } else {
                errors++;
            }

            if ((pixels_written + errors) % 5000 == 0) {
                printf("  Progresso: %d / %d pixels\n", pixels_written + errors, VRAM_SIZE);
            }
        }
    }

    free(row_buffer);
    fclose(fp);

    printf("Carregamento concluído:\n");
    printf("  - Pixels escritos: %d\n", pixels_written);
    printf("  - Erros: %d\n", errors);

    return (errors == 0) ? 0 : -1;
}

// Exibe a imagem na VGA
void display_image(void) {
    printf("Atualizando VGA...\n");
    send_refresh();
    sleep(1);
    printf("✓ Imagem exibida na VGA!\n");
}

// Zoom IN
void do_zoom_in(int algorithm) {
    printf("Fazendo Zoom IN...\n");

    if (algorithm == 1) {
        printf("  Algoritmo: Vizinho Próximo\n");
        Vizinho_Prox();
    } else {
        printf("  Algoritmo: Replicação de Pixel\n");
        Replicacao();
    }

    int timeout = 1000000;
    while (timeout-- > 0) {
        if (Flag_Done()) {
            printf("✓ Zoom IN concluído!\n");
            return;
        }
    }

    printf("✗ ERRO: Timeout no Zoom IN\n");
}

// Zoom OUT
void do_zoom_out(int algorithm) {
    printf("Fazendo Zoom OUT...\n");

    if (algorithm == 1) {
        printf("  Algoritmo: Vizinho Próximo\n");
        Decimacao();
    } else {
        printf("  Algoritmo: Média de Blocos\n");
        Media();
    }

    int timeout = 1000000;
    while (timeout-- > 0) {
        if (Flag_Done()) {
            printf("✓ Zoom OUT concluído!\n");
            return;
        }
    }

    printf("✗ ERRO: Timeout no Zoom OUT\n");
}

// Menu
void show_menu(void) {
    printf("\n╔══════════════════════════════════════╗\n");
    printf("║    COPROCESSADOR DE ZOOM - MENU     ║\n");
    printf("╚══════════════════════════════════════╝\n");
    printf("1. Carregar imagem (xadrez.bmp)\n");
    printf("2. Exibir imagem na VGA\n");
    printf("3. Zoom IN - Vizinho Próximo\n");
    printf("4. Zoom IN - Replicação de Pixel\n");
    printf("5. Zoom OUT - Vizinho Próximo\n");
    printf("6. Zoom OUT - Média de Blocos\n");
    printf("7. Reset\n");
    printf("0. Sair\n");
    printf("──────────────────────────────────────\n");
    printf("Escolha: ");
}

int main(void) {
    printf("\n╔══════════════════════════════════════╗\n");
    printf("║    INICIALIZANDO BIBLIOTECA        ║\n");
    printf("╚══════════════════════════════════════╝\n\n");
    
    Lib();  // Inicializa mmap

    printf("✓ Sistema pronto!\n\n");

    int choice;
    int running = 1;

    while (running) {
        show_menu();
        scanf("%d", &choice);
        getchar();

        switch (choice) {
            case 1:
                printf("\n[1] Carregando imagem...\n\n");
                if (load_bmp_to_fpga("xadrez.bmp") == 0) {
                    printf("\n✓ Imagem carregada com sucesso!\n");
                } else {
                    printf("\n✗ Falha ao carregar imagem\n");
                }
                break;

            case 2:
                printf("\n[2] Exibindo imagem...\n\n");
                display_image();
                break;

            case 3:
                printf("\n[3] Zoom IN (Vizinho Próximo)...\n\n");
                do_zoom_in(1);
                display_image();
                break;

            case 4:
                printf("\n[4] Zoom IN (Replicação)...\n\n");
                do_zoom_in(2);
                display_image();
                break;

            case 5:
                printf("\n[5] Zoom OUT (Vizinho Próximo)...\n\n");
                do_zoom_out(1);
                display_image();
                break;

            case 6:
                printf("\n[6] Zoom OUT (Média Blocos)...\n\n");
                do_zoom_out(2);
                display_image();
                break;

            case 7:
                printf("\n[7] Resetando coprocessador...\n\n");
                Reset();
                printf("✓ Coprocessador resetado!\n");
                break;

            case 0:
                printf("\nEncerrando...\n");
                running = 0;
                break;

            default:
                printf("✗ Opção inválida!\n");
        }
    }

    printf("\n╔══════════════════════════════════════╗\n");
    printf("║    FINALIZANDO BIBLIOTECA          ║\n");
    printf("╚══════════════════════════════════════╝\n\n");
    
    encerrarBib();

    printf("✓ Programa encerrado com sucesso.\n\n");
    return 0;
}