module Controller(
    input         clk,
    input         reset,
    
    // --- NOVAS ENTRADAS/SAÍDAS DO PROTOCOLO ---
    input         enable_from_hps,    // <<< NOVO: Sinal 'ENABLE' vindo do HPS (nível)
    input         done_from_processor,  // <<< Novo: Sinal 'DONE' vindo do ImageProcessor
    output reg    done_to_hps,        // <<< NOVO: Sinal 'DONE' indo para o HPS

    // --- Sinais para o ImageProcessor ---
    output reg    enable,             // (Sinal para o ImageProcessor)
    output reg    wren,               // (Sinal para o ImageProcessor)
    
    output reg    processing_has_run_once
);

    // --- Estados da FSM ---
    localparam S_IDLE      = 2'b00;
    localparam S_PROCESS   = 2'b01;
    localparam S_DONE_WAIT = 2'b10; // <<< NOVO ESTADO: Espera HPS baixar o ENABLE

    reg [1:0] current_state;

    // --- Lógica da Máquina de Estados e Saídas (Síncrono) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= S_IDLE;
            enable <= 1'b0;
            wren <= 1'b0;
            done_to_hps <= 1'b0;
            processing_has_run_once <= 1'b0;
        end else begin
            
            case(current_state)
                S_IDLE: begin
                    // Reseta os sinais
                    enable <= 1'b0;
                    wren <= 1'b0;
                    done_to_hps <= 1'b0;

                    // Espera o HPS ativar o 'enable'
                    if (enable_from_hps) begin
                        current_state <= S_PROCESS;
                    end
                end
                
                S_PROCESS: begin
                    // Ativa o ImageProcessor
                    enable <= 1'b1;
                    wren <= 1'b1;

                    // Espera o ImageProcessor terminar
                    if (done_from_processor) begin
                        current_state <= S_DONE_WAIT;
                        processing_has_run_once <= 1'b1; // Marca que já rodou
                    end
                end
                
                S_DONE_WAIT: begin
                    // Desliga o ImageProcessor
                    enable <= 1'b0;
                    wren <= 1'b0;
                    
                    // Sinaliza ao HPS que terminamos
                    done_to_hps <= 1'b1;

                    // Espera o HPS baixar o 'enable' para 0 (confirmando o 'done')
                    if (!enable_from_hps) begin
                        current_state <= S_IDLE;
                    end
                end
                
                default: begin
                    current_state <= S_IDLE;
                end
                
            endcase
        end
    end

endmodule