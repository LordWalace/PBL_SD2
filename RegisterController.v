// API de comunicaçaõ do HPS e FPGA

module RegisterController(

    // Interface com o Barramento do HPS (ex: Avalon-MM)
    input           clk,
    input           reset,
    input   [1:0]   address,    // Endereço para selecionar o registo
    input           chipselect,
    input           write,
    input           read,
    input   [31:0]  writedata,
    output reg [31:0]  readdata,

    // Saídas para a lógica do Coprocessador
    output  [1:0]   algorithm_select_out,
    output  [2:0]   zoom_level_out,
    output          start_pulse_out,

    // Entrada do estado do Coprocessador
    input           processing_done_in
);

    // Registadores internos que guardam os comandos do HPS
    reg [1:0] algorithm_select_reg;
    reg [2:0] zoom_level_reg;
    reg start_process_reg;

    // Lógica de escrita: O HPS escreve nos registadores
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            algorithm_select_reg <= 2'b0;
            zoom_level_reg <= 3'd2;
            start_process_reg <= 1'b0;
        end else if (chipselect && write) begin
            case (address)
                2'b00: begin // Endereço 0: Registo de Controlo
                    algorithm_select_reg <= writedata[1:0];
                    zoom_level_reg <= writedata[4:2];
                end
                2'b01: begin // Endereço 1: Registo de Início
                    start_process_reg <= writedata[0];
                end
            endcase
        end else if (start_process_reg) begin
            // Gera um pulso único e auto-limpa-se
            start_process_reg <= 1'b0;
        end
    end

    // Lógica de leitura: O HPS lê o estado do hardware
    always @(*) begin
        readdata = 32'h0; // Valor padrão
        if (chipselect && read) begin
            case (address)
                2'b10: readdata = {31'b0, processing_done_in}; // Endereço 2: Registo de Estado
            endcase
        end
    end
    
    // Liga as saídas dos registadores aos fios de controlo do seu projeto
    assign algorithm_select_out = algorithm_select_reg;
    assign zoom_level_out = zoom_level_reg;
    assign start_pulse_out = start_process_reg;

endmodule