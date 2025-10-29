module RegisterController(

    // Interface com o Barramento do HPS (assíncrono)
    input           clk,
    input           reset,
    input  [1:0]    address,     // Endereço para selecionar o registo
    input           chipselect,
    input           write,
    input           read,
    input  [31:0]   writedata,
    output reg [31:0]   readdata,

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

    // --- INÍCIO DA CORREÇÃO CDC (Clock Domain Crossing) ---
    // Precisamos de sincronizar TODAS as entradas assíncronas do HPS
    // para o domínio de 'clk' do FPGA.
    
    // Registos para guardar as versões síncronas dos sinais de entrada
    reg  [1:0]  address_sync;
    reg         chipselect_sync;
    reg  [31:0] writedata_sync;
    
    // Sincronizador de 2 estágios + Detetor de Borda para o sinal 'write'
    reg  write_q, write_q2;
    wire write_pulse_sync;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Registos de dados e controlo
            address_sync    <= 2'b0;
            chipselect_sync <= 1'b0;
            writedata_sync  <= 32'h0;
            
            // Registos do detetor de pulso de escrita
            write_q         <= 1'b0;
            write_q2        <= 1'b0;
        end else begin
            // Captura/Sincroniza todos os sinais de entrada do HPS
            // Isto garante que 'address' e 'writedata' estão estáveis
            // quando o pulso de escrita for detetado.
            address_sync    <= address;
            chipselect_sync <= chipselect;
            writedata_sync  <= writedata;
            
            // Sincroniza o sinal de escrita em 2 estágios
            write_q         <= write;
            write_q2        <= write_q;
        end
    end

    // Gera um pulso síncrono limpo de 1 ciclo quando
    // deteta a borda de subida (0 -> 1) do sinal 'write'.
    assign write_pulse_sync = write_q & ~write_q2;
    
    // --- FIM DA CORREÇÃO CDC ---


    // Lógica de escrita: O HPS escreve nos registadores
    // <<< ALTERADO: Agora usa os sinais síncronos
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            algorithm_select_reg <= 2'b0;
            zoom_level_reg <= 3'd2;
            start_process_reg <= 1'b0;
        
        // Acionado APENAS pelo pulso síncrono
        // e usa os dados/endereços que foram capturados no ciclo anterior.
        end else if (write_pulse_sync && chipselect_sync) begin
            case (address_sync) // <<< ALTERADO
                2'b00: begin // Endereço 0: Registo de Controlo
                    algorithm_select_reg <= writedata_sync[1:0]; // <<< ALTERADO
                    zoom_level_reg <= writedata_sync[4:2]; // <<< ALTERADO
                end
                2'b01: begin // Endereço 1: Registo de Início
                    start_process_reg <= writedata_sync[0]; // <<< ALTERADO
                end
            endcase
        end else if (start_process_reg) begin
            // Gera um pulso único e auto-limpa-se
            // Esta lógica interna já estava correta.
            start_process_reg <= 1'b0;
        end
    end

    // Lógica de leitura: O HPS lê o estado do hardware
    // (Não necessita de sincronização pois 'read' é combinacional)
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
    assign start_pulse_out = start_process_reg; // Este sinal é agora um pulso síncrono fiável

endmodule