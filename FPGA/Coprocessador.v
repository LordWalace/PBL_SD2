/*
 * Módulo: Coprocessador (Modificado para protocolo ENABLE/DONE)
 *
 * Descrição:
 * Este módulo top-level implementa a interface PIO com o HPS usando
 * o protocolo simplificado ENABLE/DONE.
 *
 * NOVO MAPA DE PIOs (Protocolo "DestinyWolf"):
 *
 * PIO_CONTROL_IN [31:0]
 * bit 31:    hps_reset_n (ativo baixo, ~PIO_CONTROL_IN[31])
 * bit 30:    hps_enable  (executa comando quando = 1)
 * bits [20:15]: hps_cmd (comando para o módulo)
 * - 6'h01: Escrever na ImgRam
 * - 6'h02: Escrever no RegisterController
 * - 6'h04: Iniciar Processamento (dispara o Controller.v)
 * bits [14:0]: hps_address
 *
 * PIO_DATA_IN [31:0]
 * Para RegisterController: bits [31:0] = dados completos
 * Para ImgRam:             bits [7:0]  = pixel
 *
 * PIO_DATA_OUT [31:0]
 * bit 1:  fpga_done (sinal de 'done' do Controller.v)
 * (outros bits de status mantidos)
 */
module Coprocessador (
    // Clock principal da FPGA
    input         CLOCK_50,

    // --- Saídas Físicas (VGA, Display) ---
    output        VGA_CLK,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_BLANK_N,
    output [7:0]  VGA_R,
    output [7:0]  VGA_G,
    output [7:0]  VGA_B,
    output [6:0]  HEX0,
    output [6:0]  HEX1,
    output [6:0]  HEX2,
    output [6:0]  HEX3,
    output [6:0]  HEX4,
    output [6:0]  HEX5,

    // --- Saída para Debug ---
    output [9:0]  LEDR,            // LEDs para depuração

    // --- NOVA INTERFACE DE 3 PIOs (UNIDIRECIONAL) ---
    input  [31:0] PIO_CONTROL_IN,  // HPS -> FPGA: Controlo, Endereço, Enable
    input  [31:0] PIO_DATA_IN,     // HPS -> FPGA: Dados de escrita
    output [31:0] PIO_DATA_OUT     // FPGA -> HPS: Status e dados de leitura
);

    // --- DECODIFICAÇÃO DOS PIOs (Protocolo ENABLE/DONE) ---
    
    // --- Entradas do HPS ---
    // PIO_CONTROL_IN [31:0]
    wire hps_reset           = ~PIO_CONTROL_IN[31];    // bit 31: reset ativo baixo
    wire hps_enable          =  PIO_CONTROL_IN[30];    // bit 30: <<< NOVO ENABLE >>>
    wire [5:0] hps_cmd       =  PIO_CONTROL_IN[20:15]; // bits 20:15: <<< NOVO CMD >>>
    wire [14:0] hps_address  =  PIO_CONTROL_IN[14:0];  // bits 14:0: endereço
    
    // Sinais de controlo antigos (removidos/ignorados)
    // wire hps_activate_img_write = PIO_CONTROL_IN[10];
    // wire hps_activate_reg_write = PIO_CONTROL_IN[5];
    // ... (etc)
    
    // Sinais de leitura (mantidos)
    wire hps_read_control    =  PIO_CONTROL_IN[4];
    wire [1:0] hps_address_control = PIO_CONTROL_IN[1:0]; // Endereço para RegisterController

    // PIO_DATA_IN [31:0]
    wire [31:0] hps_writedata_control = PIO_DATA_IN;      // Palavra completa de 32 bits
    wire [7:0]  hps_writedata_img     = PIO_DATA_IN[7:0]; // Apenas os 8 bits inferiores

    // Sinais de clock e de saída do RegisterController
    wire hps_clk = CLOCK_50;
    wire [31:0] hps_readdata_control; // saída do RegisterController

    // Sinais de handshake ACK (REMOVIDOS)
    // reg fpga_ack_img_write;
    // reg fpga_ack_reg_write;
    
    // --- Lógica de Comando (Protocolo ENABLE/DONE) ---
    localparam CMD_WRITE_IMGRAM  = 6'h01;
    localparam CMD_WRITE_REGCTRL = 6'h02;
    localparam CMD_START_PROCESS = 6'h04;

    wire wren_img_ram         = hps_enable & (hps_cmd == CMD_WRITE_IMGRAM);
    wire wren_reg_controller  = hps_enable & (hps_cmd == CMD_WRITE_REGCTRL);
    wire start_processing_cmd = hps_enable & (hps_cmd == CMD_START_PROCESS);
    
    // Sinal 'DONE' que vem do Controller.v e vai para o HPS
    wire fpga_done_internal;


    // --- Saída para o HPS (MODIFICADA) ---
    assign PIO_DATA_OUT = hps_read_control ? hps_readdata_control : {
        16'h0000,                 // Reserved [31:16]
        zoom_level,               // [15:13] zoom atual
        algorithm_select,         // [12:11] algoritmo atual
        6'b000000,                // Reserved [10:5]
        processing_has_run_once,  // [4] histórico de processamento
        processing_finished,      // [3] (mantido, sinal do ImageProcessor)
        1'b0,                     // [2] (Bit ACK removido)
        fpga_done_internal,       // [1] <<< NOVO SINAL 'DONE' para o HPS >>>
        1'b1                      // [0] sistema ativo
    };

    // --- Fios de Ligação ---
    wire enable_processing, processing_finished, wren_from_controller;
    wire [14:0] read_addr_to_ram;
    wire [18:0] write_addr;
    wire [7:0] pixel_out_from_processor, pixel_in_to_processor;
    wire [18:0] vga_read_addr;
    wire [7:0] vga_pixel_data;
    wire [2:0] zoom_level;
    wire [1:0] algorithm_select;
    // wire start_pulse; // Removido, vem do RegisterController mas não é mais usado
    wire processing_has_run_once;
    
    
    // <<< TODA A LÓGICA DE HANDSHAKE (Activate/ACK/Latch) FOI REMOVIDA >>>
    // (O bloco always @(posedge CLOCK_50 or posedge hps_reset) ... foi removido)
    

    // Fios para a arquitetura VGA
    wire vga_clk_25mhz;
     wire [9:0] vga_next_x, vga_next_y, is_image_area;
    wire [7:0] color_to_driver;
    wire vga_sync_dummy;
     wire [2:0] vga_display_zoom_level;

    // --- Geração do Clock de 25MHz ---
    reg clk_div_reg = 0;
    always @(posedge CLOCK_50) clk_div_reg <= ~clk_div_reg;
    assign vga_clk_25mhz = clk_div_reg;

    
    // --- Instanciação dos Módulos (MODIFICADA) ---

    // 1. Módulo de Registadores API (agora usa dados e controlo diretos)
    RegisterController control_regs (
        .clk(hps_clk), .reset(hps_reset), 
        .address(hps_address_control),     // <<< MODIFICADO (usa PIO direto)
        .chipselect(wren_reg_controller),  // <<< MODIFICADO (usa enable+cmd)
        .write(wren_reg_controller),       // <<< MODIFICADO (usa enable+cmd)
        .read(hps_read_control),         
        .writedata(hps_writedata_control), // <<< MODIFICADO (usa PIO direto)
        .readdata(hps_readdata_control),
        .algorithm_select_out(algorithm_select),
        .zoom_level_out(zoom_level),
        .start_pulse_out(), // <<< DESLIGADO (não é mais usado)
        .processing_done_in(processing_finished)
    );

    // 2. O Controller (FSM) (MODIFICADO para corresponder ao Controller.v)
    Controller main_fsm (
        .clk(CLOCK_50), 
        .reset(hps_reset), 
        
        // --- Novas portas do protocolo ENABLE/DONE ---
        .enable_from_hps(start_processing_cmd), // <<< LIGADO ao comando 'start' do HPS
        .done_from_processor(processing_finished),  // <<< LIGADO ao 'done' do ImageProcessor
        .done_to_hps(fpga_done_internal),     // <<< LIGADO ao PIO_DATA_OUT[1]

        // --- Saídas para o ImageProcessor ---
        .enable(enable_processing), 
        .wren(wren_from_controller), 
        .processing_has_run_once(processing_has_run_once)
        
        // Portas antigas (.start, .hps_writing_image, .done) removidas
    );

    // 3. Memória da Imagem (agora usa dados e controlo diretos)
    ImgRam processing_ram (
        .clock(CLOCK_50), 
        .rdaddress(read_addr_to_ram), 
        .q(pixel_in_to_processor),
        .wraddress(hps_address),       // <<< MODIFICADO (usa PIO direto)
        .data(hps_writedata_img),      // <<< MODIFICADO (usa PIO direto)
        .wren(wren_img_ram)            // <<< MODIFICADO (usa enable+cmd)
    );
     
    // 4. Processador de Imagem (Sem alterações)
    ImageProcessor processor (
        .clk(CLOCK_50), .enable(enable_processing), 
        .algorithm_select(algorithm_select), .zoom_level(zoom_level), 
        .pixel_in_from_rom(pixel_in_to_processor), .read_addr(read_addr_to_ram), 
        .pixel_out_to_ram(pixel_out_from_processor), .write_addr(write_addr), 
        .done(processing_finished) 
    );
    // 5. Memória de Vídeo (Frame Buffer) (Sem alterações)
    VdRam frame_buffer (.clock(CLOCK_50), .wren(wren_from_controller), .wraddress(write_addr), .data(pixel_out_from_processor), .rdaddress(vga_read_addr), .q(vga_pixel_data));
    
    // 6. Arquitetura de Exibição VGA (Sem alterações)
    assign vga_display_zoom_level = processing_has_run_once ? zoom_level : 3'd2;
    VGAController vga_logic_inst (.pclk(CLOCK_50), .reset(hps_reset), .zoom_level(vga_display_zoom_level), .current_x(vga_next_x), .current_y(vga_next_y), .is_image_area(is_image_area), .read_addr(vga_read_addr));
     
    assign color_to_driver = is_image_area ? vga_pixel_data : 8'h00;  
    VGA_Driver the_vga_driver (.clock(vga_clk_25mhz), .reset(hps_reset), .color_in(color_to_driver), .next_x(vga_next_x), .next_y(vga_next_y), .hsync(VGA_HS), .vsync(VGA_VS), .red(VGA_R), .green(VGA_G), .blue(VGA_B), .sync(vga_sync_dummy), .clk(VGA_CLK), .blank(VGA_BLANK_N));
     
    // 7. Driver do Display (Sem alterações)
    Informations scrolling_display (.clk(CLOCK_50), .reset(hps_reset), .algorithm_select(algorithm_select), .invalid_zoom_error(1'b0), .multiple_switches_error(1'b0), .no_switch_selected_error(1'b0), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));


    // <<< INÍCIO DO BLOCO DE DEBUG (MODIFICADO) >>>
     
    // Registos para "segurar" os pulsos
    reg  img_ram_write_latch;
    reg  start_pulse_latch;   

    always @(posedge CLOCK_50 or posedge hps_reset) begin
        if (hps_reset) begin
            img_ram_write_latch <= 1'b0;
            start_pulse_latch   <= 1'b0;
        end else begin
            
            // Latch para o *pedido* de escrita na ImgRam
            if (wren_img_ram) begin // (agora usa o novo sinal)
                img_ram_write_latch <= 1'b1;
            end
            
            // Latch para o *pedido* de 'start'
            if (start_processing_cmd) begin // (agora usa o novo sinal)
                start_pulse_latch <= 1'b1;
            end
        end
    end

    // --- Mapeamento dos Sinais de Debug para os LEDs ---
    assign LEDR[9] = ~hps_reset;            // LIGADO = Sistema FORA de reset.
    assign LEDR[8] = img_ram_write_latch;   // LIGADO = Pelo menos 1 escrita na ImgRam foi DETECTADA.
    assign LEDR[7] = start_pulse_latch;     // LIGADO = O comando 'start' foi DETECTADO.
    assign LEDR[6] = enable_processing;     // LIGADO = FSM (Controller) está no estado S_PROCESS.
    assign LEDR[5] = processing_finished;   // LIGADO = O ImageProcessor TERMINOU.
    assign LEDR[4] = hps_enable;            // <<< NOVO: LIGADO = HPS está a enviar um comando (ENABLE=1)
    assign LEDR[3] = fpga_done_internal;    // <<< NOVO: LIGADO = Controller FSM está em S_DONE_WAIT
    assign LEDR[2:0] = 3'b0;                // Não utilizados
     
    // <<< FIM DO BLOCO DE DEBUG >>>
     
endmodule