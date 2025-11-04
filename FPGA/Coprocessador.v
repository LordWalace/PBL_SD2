module Coprocessador (
    input             CLOCK_50,
    
    // --- Saídas ---
    output            VGA_CLK,
    output            VGA_HS,
    output            VGA_VS,
    output            VGA_BLANK_N,
    output     [7:0]  VGA_R,
    output     [7:0]  VGA_G,
    output     [7:0]  VGA_B,
    output     [6:0]  HEX0,
    output     [6:0]  HEX1,
    output     [6:0]  HEX2,
    output     [6:0]  HEX3,
    output     [6:0]  HEX4,
    output     [6:0]  HEX5,
    
    // --- SAÍDA DE DEBUG (LEDs) ---
    output     [9:0]  LEDR,

    // --- PIOs do HPS (Definidos no Qsys) ---
    input      [31:0] hps_data_in,      // PIO 1 (IN): Dados/Comandos
    input             hps_control_in,     // PIO 2 (IN): Strobe "data_valid"
    output     [31:0] fpga_status_out   // PIO 3 (OUT): Status/Resultado
);

    // --- 1. Gerador de Reset de Power-On (POR) ---
    // (Estava faltando no código colado)
    reg [7:0] por_shreg = 8'b0;
    always @(posedge CLOCK_50) begin
        por_shreg <= {por_shreg[6:0], 1'b1};
    end
    wire internal_power_on_reset = ~por_shreg[7]; 

    // --- 2. Sinais de Controle e Reset ---
    wire sw_reset_pulse;     // Reset do HPS (via Interface)
    
    // 'logic_reset' reseta o Controller e o Display (POR ou SW)
    wire logic_reset = internal_power_on_reset | sw_reset_pulse; 
    
    // O 'vga_reset' reseta apenas o VGA (Somente POR)
    wire vga_reset = internal_power_on_reset;

    // --- Fios de Ligação ---
    wire enable_processing, processing_finished, wren_from_controller;
    wire [18:0] write_addr;
    wire [7:0] pixel_out_from_processor, pixel_in_to_processor;
    wire [18:0] vga_read_addr;
    wire [7:0] vga_pixel_data;
    wire [2:0] zoom_level;
    wire invalid_zoom_error, processing_has_run_once;
      wire vga_clk_25mhz;
    wire [9:0] vga_next_x, vga_next_y;
    wire is_image_area;
    wire [7:0] color_to_driver, pixel_from_rom_for_vga;
    wire vga_sync_dummy;
    wire [2:0] vga_display_zoom_level;
    
    // Fios da Interface para o Controller
    wire sw_zoom_in_pulse, sw_zoom_out_pulse, sw_return_pulse;
    wire [1:0] sw_algorithm_select;
    wire sw_multiple_sw_error, sw_no_switch_selected_error;
    
    // Fios da Interface para a ImgRam (Porta A)
    wire [14:0] ram_wraddress; // (Padronizado)
    wire [7:0]  ram_data_in;   
    wire        ram_wren;    
    
    // Fio do Processador para a ImgRam (Porta B)
    wire [14:0] read_addr_to_ram; // (Padronizado)

    
    // --- Geração do Clock de 25MHz ---
    reg clk_div_reg = 0;
    always @(posedge CLOCK_50) clk_div_reg <= ~clk_div_reg;
    assign vga_clk_25mhz = clk_div_reg;

    // --- 3. Instanciação dos Módulos ---

    // 3.1. A NOVA INTERFACE
    // Conecta os PIOs ao resto do sistema
    Interface interface_inst (
        .CLOCK_50(CLOCK_50),
        .POWER_ON_RESET(internal_power_on_reset), // <-- Conectado
        
        .hps_data_in(hps_data_in),
        .hps_control_in(hps_control_in),
        .fpga_status_out(fpga_status_out),

        .cmd_reset_pulse(sw_reset_pulse),
        .cmd_zoom_in_pulse(sw_zoom_in_pulse),
        .cmd_zoom_out_pulse(sw_zoom_out_pulse),
        .cmd_return_pulse(sw_return_pulse),
        .cmd_algorithm_select(sw_algorithm_select),
        .cmd_multiple_sw_error(sw_multiple_sw_error),
        .cmd_no_sw_error(sw_no_switch_selected_error),
        
        .controller_done(processing_finished), // Do controller
        .controller_zoom_level(zoom_level), //Do controller

        .ram_wraddress(ram_wraddress), // (Padronizado)
        .ram_data_in(ram_data_in),   // (Padronizado)
        .ram_wren(ram_wren)      // (Padronizado)
    );
    
    // 3.2. O CONTROLLER (FSM)
    Controller main_fsm (
        .clk(CLOCK_50), 
        .reset(logic_reset), // <-- CORRIGIDO
        .zoom_in(sw_zoom_in_pulse),
        .zoom_out(sw_zoom_out_pulse),
        .return_to_previous(sw_return_pulse), 
        .algorithm_select(sw_algorithm_select),
        .multiple_switches_error(sw_multiple_sw_error),
        .no_switch_selected_error(sw_no_switch_selected_error),
        .done(processing_finished), 
        .enable(enable_processing), 
        .wren(wren_from_controller), 
        .zoom_level(zoom_level), 
        .invalid_zoom_error(invalid_zoom_error), 
        .processing_has_run_once(processing_has_run_once)
    );
    
    // 3.3. A NOVA RAM (Instancia o seu IP 'ImgRam.v')
    ImgRam image_ram_inst (
        .clock(CLOCK_50),
        .data(ram_data_in),
        .rdaddress(read_addr_to_ram), // Porta B (Leitura)
        .wraddress(ram_wraddress),    // Porta A (Escrita)
        .wren(ram_wren),
        .q(pixel_in_to_processor)     // Saída da Porta B
    );
    
    // 3.4. O PROCESSADOR (Lê da Porta B da ImgRam)
    ImageProcessor processor (
        .clk(CLOCK_50), 
        .enable(enable_processing), 
        .algorithm_select(sw_algorithm_select), // Usa o select do HPS
        .zoom_level(zoom_level), 
        .pixel_in_from_rom(pixel_in_to_processor), // Vem da RAM
        .read_addr(read_addr_to_ram), // Controla a Porta B da RAM
        .pixel_out_to_ram(pixel_out_from_processor), 
        .write_addr(write_addr), 
        .done(processing_finished)
    );
    
    // 3.5. Memória de Escrita (VdRam) - Não muda
    VdRam frame_buffer (
        .clock(CLOCK_50), 
        .wren(wren_from_controller), 
        .wraddress(write_addr), 
        .data(pixel_out_from_processor), 
        .rdaddress(vga_read_addr), 
        .q(vga_pixel_data)
    );
    
    // 3.6. Arquitetura de Exibição VGA
    // Instancia a RAM uma segunda vez para a leitura do VGA
    ImgRam vga_ram_reader (
        .clock(CLOCK_50),
        .data(ram_data_in), // A Porta A é partilhada
        .rdaddress(vga_read_addr[14:0]), // Porta B
        .wraddress(ram_wraddress),       // Porta A
        .wren(ram_wren),
        .q(pixel_from_rom_for_vga) // Saída do pixel
    );
    
    assign vga_display_zoom_level = processing_has_run_once ? zoom_level : 3'd2;
    VGAController vga_logic_inst (
        .pclk(CLOCK_50), 
        .reset(vga_reset), // <-- CORRIGIDO
        .zoom_level(vga_display_zoom_level), 
        .current_x(vga_next_x), 
        .current_y(vga_next_y), 
        .is_image_area(is_image_area), 
        .read_addr(vga_read_addr)
    );
    
    wire [7:0] display_pixel = processing_has_run_once ? vga_pixel_data : pixel_from_rom_for_vga;
    assign color_to_driver = is_image_area ? display_pixel : 8'h00;
    
    VGA_Driver the_vga_driver (
        .clock(vga_clk_25mhz), 
        .reset(vga_reset), // <-- CORRIGIDO
        .color_in(color_to_driver), 
        .next_x(vga_next_x), 
        .next_y(vga_next_y), 
        .hsync(VGA_HS), 
        .vsync(VGA_VS), 
        .red(VGA_R), 
        .green(VGA_G), 
        .blue(VGA_B), 
        .sync(vga_sync_dummy), 
        .clk(VGA_CLK), 
        .blank(VGA_BLANK_N)
    );   
    
    // 3.7. Driver do Display de 7 Segmentos
    Informations scrolling_display (
        .clk(CLOCK_50), 
        .reset(logic_reset), // <-- CORRIGIDO
        .algorithm_select(sw_algorithm_select), // Vem da interface
        .invalid_zoom_error(invalid_zoom_error), 
        .multiple_switches_error(sw_multiple_sw_error), // Vem da interface
        .no_switch_selected_error(sw_no_switch_selected_error), // Vem da interface
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5)
    );
    
    // --- Lógica de Latch para LEDs de Debug ---
    reg led_latch_hps_strobe_r = 1'b0;
    reg led_latch_proc_finished_r = 1'b0;
    reg led_latch_ram_wren_r = 1'b0;
    reg led_latch_sw_reset_r = 1'b0; // (Renomeado)

    // O 'internal_power_on_reset' limpa os latches
    always @(posedge CLOCK_50 or posedge internal_power_on_reset) begin
        if (internal_power_on_reset) begin
            led_latch_hps_strobe_r    <= 1'b0;
            led_latch_proc_finished_r <= 1'b0;
            led_latch_ram_wren_r      <= 1'b0;
            led_latch_sw_reset_r      <= 1'b0;
        end else begin
            
            // O 'sw_reset_pulse' também limpa os latches
            if (sw_reset_pulse) begin
                led_latch_hps_strobe_r    <= 1'b0;
                led_latch_proc_finished_r <= 1'b0;
                led_latch_ram_wren_r      <= 1'b0;
                led_latch_sw_reset_r      <= 1'b1; // Mostra que o reset aconteceu
            end else begin
                // Trava os eventos
                if (hps_control_in) begin // (Usa o assíncrono para ver *qualquer* atividade)
                    led_latch_hps_strobe_r <= 1'b1;
                end
                if (processing_finished) begin
                    led_latch_proc_finished_r <= 1'b1;
                end
                if (ram_wren) begin
                    led_latch_ram_wren_r <= 1'b1;
                end
            end
        end
    end
    
    // --- LÓGICA DE DEBUG (LEDs) ---
    assign LEDR[0] = led_latch_hps_strobe_r;    // LED 0: (LATCH) HPS tentou enviar comando
    assign LEDR[1] = enable_processing;         // LED 1: (NÍVEL) Em processamento
    assign LEDR[2] = led_latch_proc_finished_r; // LED 2: (LATCH) Processamento terminou
    assign LEDR[3] = led_latch_ram_wren_r;      // LED 3: (LATCH) HPS escreveu na RAM
    assign LEDR[4] = fpga_status_out[0];        // LED 4: (NÍVEL) FPGA Pronta
    assign LEDR[5] = fpga_status_out[1];        // LED 5: (NÍVEL) Resultado Pronto
    assign LEDR[6] = invalid_zoom_error;        // LED 6: (NÍVEL) Erro de Zoom
    assign LEDR[7] = sw_multiple_sw_error;      // LED 7: (NÍVEL) Erro Múltiplo
    assign LEDR[8] = sw_no_switch_selected_error; // LED 8: (NÍVEL) Nenhum selecionado (DEVE ACENDER NO INÍCIO)
    assign LEDR[9] = led_latch_sw_reset_r;      // LED 9: (LATCH) Reset por Software recebido

endmodule