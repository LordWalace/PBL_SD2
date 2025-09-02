module Coprocessador (
    // ---- Entradas Globais da Placa ----
    input           CLOCK_50,
    input   [3:0]   KEY,
    input   [3:0]   SW,

    // ---- Saídas VGA ----
    output          VGA_CLK,
    output          VGA_HS,
    output          VGA_VS,
    output          VGA_BLANK_N,
    output  [7:0]   VGA_R,
    output  [7:0]   VGA_G,
    output  [7:0]   VGA_B
);

    // --- Sinais de Controlo ---
    wire reset = !KEY[0];
    wire start_process = !KEY[1];
    wire [1:0] algorithm_select = SW[1:0];

    // Gera um pulso único para o sinal de início
    reg prev_start;
    wire start_pulse;
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) prev_start <= 1'b0;
        else prev_start <= start_process;
    end
    assign start_pulse = start_process & ~prev_start;

    // --- Fios de Ligação Internos ---
    wire enable_processing, processing_finished;
    wire [15:0] base_read_addr;
    wire [16:0] write_addr; // CORRIGIDO: Largura do endereço para 17 bits
    wire [7:0] pixel_out_from_resizer;
    wire wren_from_controller;

    // Fios para os 4 pixels lidos da ROM
    wire [7:0] pixel_from_rom_p0, pixel_from_rom_p1, pixel_from_rom_p2, pixel_from_rom_p3;

    // Fios para a RAM de vídeo
    wire [16:0] vga_read_addr; // CORRIGIDO: Largura do endereço para 17 bits
    wire [7:0] vga_pixel_data;

    // --- Instanciação dos Módulos ---

    // 1. Controlador Principal (FSM)
    Controller main_fsm (
        .clk(CLOCK_50),
        .reset(reset),
        .start(start_pulse),
        .done(processing_finished),
        .enable(enable_processing),
        .wren(wren_from_controller)
    );

    // 2. Memórias de Leitura da Imagem Original (4 instâncias)
    // CORRIGIDO: O nome do módulo é 'ImgRom', conforme gerado pelo Quartus.
    localparam IMG_WIDTH = 160;
    ImgRom rom0 (.clock(CLOCK_50), .address(base_read_addr), .q(pixel_from_rom_p0));
    ImgRom rom1 (.clock(CLOCK_50), .address(base_read_addr + 1), .q(pixel_from_rom_p1));
    ImgRom rom2 (.clock(CLOCK_50), .address(base_read_addr + IMG_WIDTH), .q(pixel_from_rom_p2));
    ImgRom rom3 (.clock(CLOCK_50), .address(base_read_addr + IMG_WIDTH + 1), .q(pixel_from_rom_p3));

    // 3. Gestor de Algoritmos (ZoomSelection)
    ZoomSelection resizer (
        .clk(CLOCK_50),
        .enable(enable_processing),
        .algorithm_select(algorithm_select),
        .pixel_in_p0(pixel_from_rom_p0),
        .pixel_in_p1(pixel_from_rom_p1),
        .pixel_in_p2(pixel_from_rom_p2),
        .pixel_in_p3(pixel_from_rom_p3),
        .pixel_out(pixel_out_from_resizer),
        .base_read_addr(base_read_addr),
        .write_addr(write_addr),
        .done(processing_finished)
    );

    // 4. Memória de Escrita (VdRam)
    // CORRIGIDO: Nomes das portas atualizados para corresponder ao módulo gerado 'VdRam.v'
    VdRam frame_buffer (
        .clock(CLOCK_50),
        .wren(wren_from_controller),
        .wraddress(write_addr),
        .data(pixel_out_from_resizer),
        .rdaddress(vga_read_addr),
        .q(vga_pixel_data)
    );

    // 5. Controlador VGA
    VGAController vga_inst (
        .pclk(CLOCK_50), // Idealmente, usar um PLL para gerar o clock de pixel correto
        .reset(reset),
        .h_sync(VGA_HS),
        .v_sync(VGA_VS),
        .video_on(VGA_BLANK_N),
        .read_addr(vga_read_addr)
    );

    // Lógica de Saída para o Monitor
    assign VGA_CLK = CLOCK_50;
    assign VGA_R = VGA_BLANK_N ? vga_pixel_data : 8'h00;
    assign VGA_G = VGA_BLANK_N ? vga_pixel_data : 8'h00;
    assign VGA_B = VGA_BLANK_N ? vga_pixel_data : 8'h00;

endmodule