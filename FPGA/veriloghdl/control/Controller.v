module Controller(
    input           clk,
    input           reset,
    input           start,              // Pulso para iniciar o processamento
    input           hps_writing_image,  // <<< NOVA ENTRADA: Indica que o HPS está a escrever na RAM
    input           done,               // Sinal do ImageProcessor a indicar que terminou

    output reg      enable,
    output reg      wren,
    output reg      processing_has_run_once
);

    // --- Estados da FSM ---
    localparam S_IDLE    = 2'b00;
    localparam S_PROCESS = 2'b01;
    localparam S_MEMORY  = 2'b10; // <<< NOVO ESTADO 
    
    reg [1:0] current_state, next_state;

    // --- Lógica de Estado ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            processing_has_run_once <= 1'b0;
        end else begin
            if (current_state == S_PROCESS && done) begin
                processing_has_run_once <= 1'b1;
            end
        end
    end

    // --- Lógica da Máquina de Estados ---
    always @(posedge clk or posedge reset) begin
        if (reset) current_state <= S_IDLE;
        else current_state <= next_state;
    end

    // --- Lógica de Transição e Saídas ---
    always @(*) begin
        next_state = current_state;
        enable = 1'b0;
        wren = 1'b0;

        // O acesso à memória pelo HPS tem a prioridade mais alta
        if (hps_writing_image) begin
            next_state = S_MEMORY;
        end else begin
            case(current_state)
                S_IDLE: 
                    if (start) begin
                        next_state = S_PROCESS;
                    end
                S_PROCESS: 
                    if (done) begin
                        next_state = S_IDLE;
                    end
                S_MEMORY: 
                    // Se o HPS terminou de aceder à memória, volta ao estado ocioso
                    // (Com um pulso, !hps_writing_image será verdade no ciclo seguinte)
                    if (!hps_writing_image) begin
                        next_state = S_IDLE;
                    end
            endcase
        end
        
        // As saídas só são ativadas no estado de processamento
        if (next_state == S_PROCESS) begin
            enable = 1'b1;
            wren = 1'b1;
        end
    end

endmodule