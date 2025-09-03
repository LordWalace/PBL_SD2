module Controller(
    input           clk,
    input           reset,
    input           zoom_in,
    input           zoom_out,
    input   [1:0]   algorithm_select,
    input           multiple_switches_error,
    input           no_switch_selected_error,
    input           done,
    output reg      enable,
    output reg      wren,
    output reg [2:0]  zoom_level,
    output reg      invalid_zoom_error
);

    localparam S_IDLE    = 2'b00;
    localparam S_PROCESS = 2'b01;
    localparam S_WRITE   = 2'b10;
    
    reg [1:0] current_state, next_state;

    // --- Fios para Lógica de Validação (Movidos para cá) ---
    wire is_zoom_in_request;
    wire is_zoom_out_request;
    wire start_condition;

    // --- Lógica de Zoom com 5 níveis ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            zoom_level <= 3'd2; // Começa em 1x (nível 2)
        end else if (next_state == S_IDLE) begin // Só muda o zoom quando não está a processar
            if (is_zoom_in_request && zoom_level < 4) begin
                zoom_level <= zoom_level + 1;
            end else if (is_zoom_out_request && zoom_level > 0) begin
                zoom_level <= zoom_level - 1;
            end
        end
    end

    // --- Lógica da Máquina de Estados ---
    always @(posedge clk or posedge reset) begin
        if (reset) current_state <= S_IDLE;
        else current_state <= next_state;
    end

    // --- Lógica Combinacional para Validação e Transição ---
    assign is_zoom_in_request = zoom_in && (algorithm_select == 2'b00 || algorithm_select == 2'b01);
    assign is_zoom_out_request = zoom_out && (algorithm_select == 2'b10 || algorithm_select == 2'b11);
    assign start_condition = !multiple_switches_error && !no_switch_selected_error && 
                           ((is_zoom_in_request && zoom_level < 4) || (is_zoom_out_request && zoom_level > 0));

    always @(*) begin
        next_state = current_state;
        invalid_zoom_error = 1'b0; // Padrão: sem erro

        // Lógica para gerar o erro de zoom inválido
        if ((zoom_in && (algorithm_select == 2'b10 || algorithm_select == 2'b11)) || 
            (zoom_out && (algorithm_select == 2'b00 || algorithm_select == 2'b01))) begin
            invalid_zoom_error = 1'b1;
        end

        case(current_state)
            S_IDLE:
                if (start_condition) 
                    next_state = S_PROCESS;
            S_PROCESS:
                if (done) 
                    next_state = S_WRITE;
            S_WRITE:
                next_state = S_IDLE;
        endcase
    end

    // --- Geração de Saídas ---
    always @(*) begin
        enable = (current_state == S_PROCESS);
        wren = (current_state == S_WRITE);
    end

endmodule