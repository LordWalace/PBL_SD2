module Interface (
    input             CLOCK_50,
    input             POWER_ON_RESET, // <-- Reset de Power-On

    // --- Lado do HPS (Qsys PIOs) ---
    input      [31:0] hps_data_in,
    input             hps_control_in,
    output reg [31:0] fpga_status_out,

    // --- Lado do FPGA (Controller e RAM) ---
    output reg        cmd_reset_pulse,
    output reg        cmd_zoom_in_pulse,
    output reg        cmd_zoom_out_pulse,
    output reg        cmd_return_pulse,
    
    output     [1:0]  cmd_algorithm_select,
    output            cmd_multiple_sw_error,
    output            cmd_no_sw_error,

    input             controller_done,
    input      [2:0]  controller_zoom_level,

    // Conexão com a ImgRam (Porta A de Escrita)
    output reg [14:0] ram_wraddress,
    output reg [7:0]  ram_data_in,
    output reg        ram_wren
    
    // (NÃO HÁ SAÍDAS DE DEBUG)
);

    // --- 1. Sincronização e Detecção de Pulso (CDC) ---
    reg hps_control_sync_r1 = 1'b0;
    reg hps_control_sync_r2 = 1'b0;
    reg hps_control_sync_last_r = 1'b0;
    
    always @(posedge CLOCK_50) begin
        hps_control_sync_r1     <= hps_control_in;
        hps_control_sync_r2     <= hps_control_sync_r1;
        hps_control_sync_last_r <= hps_control_sync_r2;
    end
    
    wire hps_data_valid_pulse = hps_control_sync_r2 & ~hps_control_sync_last_r;

    // --- 2. Registradores de Dados e Status ---
    reg [31:0] hps_data_in_latched;
    reg        result_valid_reg;
    reg [29:0] result_data_reg;

    // --- 3. FSM de Handshake ---
    localparam STATE_IDLE   = 2'b00;
    localparam STATE_DECODE = 2'b01;
    localparam STATE_BUSY   = 2'b10;

    reg [1:0] fsm_state; 

    // Registradores internos
    reg [1:0]  cmd_algorithm_select_reg;
    reg        cmd_multiple_sw_error_reg;
    reg        cmd_no_sw_error_reg;

    assign cmd_algorithm_select  = cmd_algorithm_select_reg;
    assign cmd_multiple_sw_error = cmd_multiple_sw_error_reg;
    assign cmd_no_sw_error       = cmd_no_sw_error_reg;

    // --- 4. Decodificação (Lógica Combinacional) ---
    wire decode_strobe = (fsm_state == STATE_DECODE);

    wire is_ram_write_command  = hps_data_in_latched[31];
    wire is_control_command    = !hps_data_in_latched[31];
    wire is_ack_result_command = (hps_data_in_latched[31:0] == 32'h0000_00FF); 

    // Comandos de Controle
    wire cmd_zoom_in    = hps_data_in_latched[0];
    wire cmd_zoom_out   = hps_data_in_latched[1];
    wire cmd_return     = hps_data_in_latched[2];
    wire cmd_sw_reset   = hps_data_in_latched[3];
    wire [1:0] cmd_algo = hps_data_in_latched[5:4];
    wire cmd_err_multi  = hps_data_in_latched[6];
    wire cmd_err_none   = hps_data_in_latched[7]; // Este bit vem do HPS
    
    wire cmd_causes_busy = cmd_zoom_in | cmd_zoom_out | cmd_return;

    // --- 5. Lógica Sequencial ÚNICA (FSM e Saídas) ---
    always @(posedge CLOCK_50 or posedge POWER_ON_RESET) begin
        if (POWER_ON_RESET) begin
            // ESTADO DE INICIALIZAÇÃO 100% GARANTIDO
            fsm_state                 <= STATE_IDLE;
            hps_data_in_latched       <= 32'b0;
            result_valid_reg          <= 1'b0;
            result_data_reg           <= 30'b0;
            
            cmd_reset_pulse           <= 1'b0;
            cmd_zoom_in_pulse         <= 1'b0;
            cmd_zoom_out_pulse        <= 1'b0;
            cmd_return_pulse          <= 1'b0;
            ram_wren                  <= 1'b0;
            
            // --- CORREÇÃO: Começa com 'nenhum selecionado' (erro=1) ---
            cmd_algorithm_select_reg  <= 2'b00; // O valor não importa
            cmd_multiple_sw_error_reg <= 1'b0;
            cmd_no_sw_error_reg       <= 1'b1; // <-- ESTA É A CORREÇÃO
            
        end else begin
            
            // --- Lógica de Transição da FSM ---
            case (fsm_state)
                STATE_IDLE: begin
                    if (hps_data_valid_pulse) begin
                        hps_data_in_latched <= hps_data_in;
                        fsm_state           <= STATE_DECODE;
                    end
                end
                
                STATE_DECODE: begin
                    if (is_ram_write_command) begin
                        fsm_state <= STATE_IDLE;
                    end else if (is_ack_result_command) begin
                        fsm_state <= STATE_IDLE;
                    end else if (is_control_command) begin
                        if (cmd_causes_busy) begin
                            fsm_state <= STATE_BUSY;
                        end else begin
                            fsm_state <= STATE_IDLE;
                        end
                    end else begin
                         fsm_state <= STATE_IDLE;
                    end
                end

                STATE_BUSY: begin
                    if (controller_done) begin
                        fsm_state <= STATE_IDLE;
                    end
                end
            endcase

            // --- Lógica de Geração de Saída ---
            
            cmd_reset_pulse    <= 1'b0;
            cmd_zoom_in_pulse  <= 1'b0;
            cmd_zoom_out_pulse <= 1'b0;
            cmd_return_pulse   <= 1'b0;
            ram_wren           <= 1'b0;

            if (decode_strobe) begin
                if (is_ram_write_command) begin
                    ram_wren      <= 1'b1;
                
                end else if (is_ack_result_command) begin
                    result_valid_reg <= 1'b0;
                    result_data_reg  <= 30'b0;

                end else if (is_control_command) begin
                    if (cmd_sw_reset) begin
                        // --- CORREÇÃO: Reseta para o estado 'nenhum selecionado' ---
                        cmd_reset_pulse           <= 1'b1;
                        cmd_algorithm_select_reg  <= 2'b00; // Valor não importa
                        cmd_multiple_sw_error_reg <= 1'b0;
                        cmd_no_sw_error_reg       <= 1'b1; // <-- ESTA É A CORREÇÃO
                    end
                    else 
                        cmd_zoom_in_pulse  <= cmd_zoom_in;
                        cmd_zoom_out_pulse <= cmd_zoom_out;
                        cmd_return_pulse   <= cmd_return;
                        
                        // Sinais de Nível (agora são controlados pelo HPS)
                        cmd_algorithm_select_reg  <= cmd_algo;
                        cmd_multiple_sw_error_reg <= cmd_err_multi;
                        cmd_no_sw_error_reg       <= cmd_err_none; // <-- HPS controla
                end
            end
            
            if (fsm_state == STATE_BUSY && controller_done) begin
                result_valid_reg <= 1'b1;
                result_data_reg  <= {27'b0, controller_zoom_level};
            end
        end // Fim do 'else' (não-reset)
    end // Fim do 'always'

    // --- 6. Lógica da RAM (Combinacional) ---
    always @(*) begin
        ram_wraddress = hps_data_in_latched[14:0];
        ram_data_in   = hps_data_in_latched[23:16];
    end

    // --- 7. Lógica de Saída (Status para HPS) ---
    always @(*) begin
        fpga_status_out[0]    = (fsm_state == STATE_IDLE); // 'fpga_ready'
        fpga_status_out[1]    = result_valid_reg;
        fpga_status_out[31:2] = result_data_reg;
    end

endmodule