#ifndef COPROCESSADOR_Z_H
#define COPROCESSADOR_Z_H

#ifdef __cplusplus
extern "C" {
#endif

// Inicializa o mapeamento e controle do coprocessador (abre /dev/mem e faz mmap)
void iniciarCoprocessor(void);

// Finaliza/limpa o ambiente do coprocessador (unmap e close)
void encerrarCoprocessor(void);

// Emite pulso de reset no coprocessador
void resetCoprocessor(void);

// Configura algoritmo (algoritmo: 0 a 3) e zoom (1, 2, 4, 8, etc)
void configurar_algoritmo_zoom(unsigned algoritmo, unsigned zoom);

// Escreve um pixel na ImgRam (endereco: [0, tamanho_img-1], valor: 0-255)
void escrever_pixel(unsigned endereco, unsigned valor);

// Dispara o start de processamento do coprocessador (FSM/zoom)
void start_processing(void);

// Aguarda finalizar o processamento (polling status bit 3)
void aguardar_processamento(void);

#ifdef __cplusplus
}
#endif

#endif // COPROCESSADOR_Z_H