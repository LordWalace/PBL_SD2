module Controller(
    input clk,
    input reset,
    input start,
    input done,
    output reg enable,
    output reg wren
);

    // Definição dos estados
    localparam S_IDLE = 2'b00;
    localparam S_PROCESSING = 2'b01;
    localparam S_FINISH = 2'b10;

    reg [1:0] current_state, next_state;

    // Lógica de transição de estado
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= S_IDLE;
        else
            current_state <= next_state;
    end

    // Lógica do próximo estado
    always @(*) begin
        next_state = current_state;
        case(current_state)
            S_IDLE:
                if (start) next_state = S_PROCESSING;
            S_PROCESSING:
                if (done) next_state = S_FINISH;
            S_FINISH:
                next_state = S_IDLE;
        endcase
    end

    // Lógica de saída
    always @(*) begin
        enable = 1'b0;
        wren = 1'b0;
        case(current_state)
            S_PROCESSING:
                enable = 1'b1;
            S_FINISH:
                wren = 1'b1;
        endcase
    end

endmodule