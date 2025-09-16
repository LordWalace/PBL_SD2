module Controller(
    input           clk,
    input           reset,
    input           zoom_in,
    input           zoom_out,
    input           return_to_previous,      // <<< NOVA ENTRADA
    input   [1:0]   algorithm_select,
    input           multiple_switches_error,
    input           no_switch_selected_error,
    input           done,
    output reg      enable,
    output reg      wren,
    output reg [2:0]  zoom_level,
    output reg      invalid_zoom_error,
    output reg      processing_has_run_once
);

    // --- Estados da FSM (Simplificada e Corrigida) ---
    localparam S_IDLE    = 1'b0;
    localparam S_PROCESS = 1'b1;
    
    reg current_state, next_state;

    // --- Fios e Registadores para Lógica de Controlo ---
    wire is_zoom_in_request;
    wire is_zoom_out_request;
    wire start_condition;
    reg [2:0] prev_zoom_level; // <<< NOVA MEMÓRIA PARA O ZOOM ANTERIOR

    // --- Lógica de Controlo de Estado (Sequencial) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            zoom_level <= 3'd2; // Começa em 1.0x (nível 2)
            prev_zoom_level <= 3'd2; // Inicializa a memória do zoom anterior
            processing_has_run_once <= 1'b0;
        end else begin
            // A lógica de zoom e de "voltar atrás" só é executada no estado IDLE
            if (current_state == S_IDLE) begin
                if (return_to_previous) begin
                    zoom_level <= prev_zoom_level; // Restaura o zoom anterior						
                end
                else if (is_zoom_in_request && zoom_level < 4) begin
                    prev_zoom_level <= zoom_level; // Guarda o estado atual ANTES de mudar
                    zoom_level <= zoom_level + 1;
                end else if (is_zoom_out_request && zoom_level > 0) begin
                    prev_zoom_level <= zoom_level; // Guarda o estado atual ANTES de mudar
                    zoom_level <= zoom_level - 1;
                end
            end
            // Ativa a "bandeira" que indica que um processamento já ocorreu
            if (current_state == S_PROCESS && done) begin
                processing_has_run_once <= 1'b1;
            end
        end
    end

    // --- Lógica da Máquina de Estados (Sequencial) ---
    always @(posedge clk or posedge reset) begin
        if (reset) current_state <= S_IDLE;
        else current_state <= next_state;
    end

    // --- Lógica Combinacional ---
    assign is_zoom_in_request = zoom_in && (algorithm_select == 2'b00 || algorithm_select == 2'b01);
    assign is_zoom_out_request = zoom_out && (algorithm_select == 2'b10 || algorithm_select == 2'b11);
    
    // O processamento agora também é acionado pelo botão de "voltar atrás"
    assign start_condition = !multiple_switches_error && !no_switch_selected_error && 
                           (return_to_previous || (is_zoom_in_request && zoom_level < 4) || (is_zoom_out_request && zoom_level > 0));

    always @(*) begin
        next_state = current_state;
        invalid_zoom_error = 1'b0;

        // Gera o erro de "Zoom Inválido"
        if ((zoom_in && (algorithm_select == 2'b10 || algorithm_select == 2'b11)) || 
            (zoom_out && (algorithm_select == 2'b00 || algorithm_select == 2'b01))) begin
            invalid_zoom_error = 1'b1;
        end

        // Lógica de transição da FSM
        case(current_state)
            S_IDLE: 
                if (start_condition) 
                    next_state = S_PROCESS;
            S_PROCESS: 
                if (done) 
                    next_state = S_IDLE;
        endcase
    end

    // Geração das saídas de controlo - CORRIGIDO
    always @(*) begin
        // A habilitação do processador E da escrita na RAM ocorrem
        // durante todo o estado de processamento.
        enable = (current_state == S_PROCESS);
        wren = (current_state == S_PROCESS);
    end

endmodule
