module VGAController(
    input           pclk,         // Clock do sistema (pode ser 50MHz)
    input           reset,
    input   [2:0]   zoom_level,   // Nível de zoom atual (vindo da FSM)
    input   [9:0]   current_x,    // Coordenada X atual (vinda do vga_driver)
    input   [9:0]   current_y,    // Coordenada Y atual (vinda do vga_driver)

    output          is_image_area,// Informa se a coordenada atual está dentro da imagem
    output  [18:0]  read_addr     // Endereço de leitura para a VdRam
);

    // --- Parâmetros do Ecrã VGA ---
    localparam H_DISPLAY=640;
    localparam V_DISPLAY=480;

    // --- Fios para a Lógica de Centralização ---
    wire [9:0] IMG_WIDTH_OUT;
    wire [9:0] IMG_HEIGHT_OUT;
    wire [9:0] H_OFFSET;
    wire [9:0] V_OFFSET;

    // Determina o tamanho da imagem de saída com base no zoom_level
    assign IMG_WIDTH_OUT = (zoom_level == 3'd4) ? 640 :
                           (zoom_level == 3'd3) ? 320 :
                           (zoom_level == 3'd2) ? 160 :
                           (zoom_level == 3'd1) ? 80  : 40;

    assign IMG_HEIGHT_OUT = (zoom_level == 3'd4) ? 480 :
                            (zoom_level == 3'd3) ? 240 :
                            (zoom_level == 3'd2) ? 120 :
                            (zoom_level == 3'd1) ? 60  : 30;

    // Calcula o deslocamento (offset) para centrar a imagem no ecrã
    assign H_OFFSET = (H_DISPLAY - IMG_WIDTH_OUT) / 2;
    assign V_OFFSET = (V_DISPLAY - IMG_HEIGHT_OUT) / 2;

    // Verifica se a coordenada atual (current_x, current_y) está dentro da área da imagem
    assign is_image_area = (current_x >= H_OFFSET) && (current_x < H_OFFSET + IMG_WIDTH_OUT) &&
                           (current_y >= V_OFFSET) && (current_y < V_OFFSET + IMG_HEIGHT_OUT);

    // Calcula o endereço de leitura correspondente na VdRam
    assign read_addr = is_image_area ? ((current_y - V_OFFSET) * IMG_WIDTH_OUT) + (current_x - H_OFFSET) : 0;

endmodule