module Informations (
    input           clk,
    input           reset,
    input   [1:0]   algorithm_select,
    input           invalid_zoom_error,
    input           multiple_switches_error,
    input           no_switch_selected_error,

    output  [6:0]   HEX0,
    output  [6:0]   HEX1,
    output  [6:0]   HEX2,
    output  [6:0]   HEX3,
    output  [6:0]   HEX4,
    output  [6:0]   HEX5
);

    // Divisor de clock para controlar a velocidade da rolagem.
    reg [24:0] scroll_counter;
    wire scroll_tick;

    always @(posedge clk or posedge reset) begin
        if (reset) scroll_counter <= 0;
        else if (scroll_tick) scroll_counter <= 0;
        else scroll_counter <= scroll_counter + 1;
    end
    assign scroll_tick = (scroll_counter == 25'd12_000_000);

    // Registadores para o estado do display
    reg [4:0] text_pointer;
    reg [7:0] text_data [0:31];
    reg [1:0] last_algorithm_select;
    reg last_invalid_zoom_error, last_multiple_switches_error, last_no_switch_selected_error;
    integer i;
    
    wire error_state_changed;
    wire no_error;
    // Lógica para selecionar o texto a ser exibido

    // Lógica para selecionar o texto a ser exibido - TEXTOS EM INGLÊS
    always @(*) begin
        for (i = 0; i < 32; i = i + 1) text_data[i] = " ";

        if (no_switch_selected_error) begin
            // "      SELECT AN ALGORITHM   "
            text_data[6] = "S"; text_data[7] = "E"; text_data[8] = "L"; text_data[9] = "E"; text_data[10] = "C"; text_data[11] = "T";
            text_data[12] = " "; text_data[13] = "A"; text_data[14] = "N";
            text_data[15] = " "; text_data[16] = "A"; text_data[17] = "L"; text_data[18] = "G";
            text_data[19] = "O"; text_data[20] = "R"; text_data[21] = "I"; text_data[22] = "T";
            text_data[23] = "H"; text_data[24] = "M";
        end else if (multiple_switches_error) begin
            // "      ERROR SELECTION       "
				text_data[16] = "E"; text_data[17] = "R"; text_data[18] = "R";
            text_data[19] = "O"; text_data[20] = "R"; text_data[15] = " "; 
            text_data[6] = "S"; text_data[7] = "E"; text_data[8] = "L"; text_data[9] = "E"; text_data[10] = "C"; text_data[11] = "T";
            text_data[12] = "I"; text_data[13] = "O"; text_data[14] = "N";
            // "      SELECTION ERROR       "
            text_data[6] = "S"; text_data[7] = "E"; text_data[8] = "L"; text_data[9] = "E"; text_data[10] = "C"; text_data[11] = "T";
            text_data[12] = "I"; text_data[13] = "O"; text_data[14] = "N";
            text_data[15] = " "; text_data[16] = "E"; text_data[17] = "R"; text_data[18] = "R";
            text_data[19] = "O"; text_data[20] = "R";
        end else if (invalid_zoom_error) begin
            // "      INVALID ZOOM          "
            text_data[6] = "I"; text_data[7] = "N"; text_data[8] = "V"; text_data[9] = "A"; text_data[10] = "L"; text_data[11] = "I";
            text_data[12] = "D"; text_data[13] = " "; text_data[14] = "Z"; text_data[15] = "O";
            text_data[16] = "O"; text_data[17] = "M";
        end else begin
            case(algorithm_select)
                2'b00: begin // NEAREST NEIGHBOR
                    text_data[6] = "N"; text_data[7] = "E"; text_data[8] = "A"; text_data[9] = "R";
                    text_data[10] = "E"; text_data[11] = "S"; text_data[12] = "T";
                    text_data[13] = " "; text_data[14] = "N"; text_data[15] = "E";
                    text_data[16] = "I"; text_data[17] = "G"; text_data[18] = "H";
                    text_data[19] = "B"; text_data[20] = "O"; text_data[21] = "R";
                end
                2'b01: begin // PIXEL REPLICATION
                    text_data[6] = "P"; text_data[7] = "I"; text_data[8] = "X"; text_data[9] = "E";
                    text_data[10] = "L"; text_data[11] = " "; text_data[12] = "R";
                    text_data[13] = "E"; text_data[14] = "P"; text_data[15] = "L";
                    text_data[16] = "I"; text_data[17] = "C"; text_data[18] = "A";
                    text_data[19] = "T"; text_data[20] = "I"; text_data[21] = "O";
                    text_data[22] = "N";
                end
                2'b10: begin // DECIMATION
                    text_data[6] = "D"; text_data[7] = "E"; text_data[8] = "C"; text_data[9] = "I";
                    text_data[10] = "M"; text_data[11] = "A"; text_data[12] = "T";
                    text_data[13] = "I"; text_data[14] = "O"; text_data[15] = "N";
                end
                2'b11: begin // BLOCK AVERAGING
                    text_data[6] = "B"; text_data[7] = "L"; text_data[8] = "O"; text_data[9] = "C";
                    text_data[10] = "K"; text_data[11] = " "; text_data[12] = "A";
                    text_data[13] = "V"; text_data[14] = "E"; text_data[15] = "R";
                    text_data[16] = "A"; text_data[17] = "G"; text_data[18] = "I";
                    text_data[19] = "N"; text_data[20] = "G";
                end
            endcase
        end
    end

    // Lógica para controlar o ponteiro de rolagem do texto
    assign error_state_changed = (invalid_zoom_error != last_invalid_zoom_error) || (multiple_switches_error != last_multiple_switches_error) || (no_switch_selected_error != last_no_switch_selected_error);
    assign no_error = !invalid_zoom_error && !multiple_switches_error && !no_switch_selected_error;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            text_pointer <= 0;
            last_algorithm_select <= 2'b00;
            last_invalid_zoom_error <= 1'b0;
            last_multiple_switches_error <= 1'b0;
            last_no_switch_selected_error <= 1'b0;
        end else begin
            last_algorithm_select <= algorithm_select;
            last_invalid_zoom_error <= invalid_zoom_error;
            last_multiple_switches_error <= multiple_switches_error;
            last_no_switch_selected_error <= no_switch_selected_error;
            
            if (error_state_changed || (no_error && (algorithm_select != last_algorithm_select))) begin
                text_pointer <= 0;
            end else if (scroll_tick) begin
                if (text_pointer >= 26) text_pointer <= 0;
                else text_pointer <= text_pointer + 1;
            end
        end
    end

    // FUNÇÃO DE DESCODIFICAÇÃO CORRIGIDA
    // Converte um caracter ASCII para um padrão de 7 segmentos.
    // O padrão é {g, f, e, d, c, b, a}, e um '0' acende o segmento (ativo baixo).    // =============================================================================
    function [6:0] char_to_segments;
        input [7:0] char;
        begin
            case(char)
                // Letras Maiúsculas
                "A": char_to_segments = 7'b0001000; "B": char_to_segments = 7'b0000011;
                "C": char_to_segments = 7'b1000110; "D": char_to_segments = 7'b1100000;
                "E": char_to_segments = 7'b0000110; "F": char_to_segments = 7'b0001110;
                "G": char_to_segments = 7'b1000010; "H": char_to_segments = 7'b0001011;
                "I": char_to_segments = 7'b1001111; "J": char_to_segments = 7'b1100001;
                "K": char_to_segments = 7'b0001010; "L": char_to_segments = 7'b1000111;
                "M": char_to_segments = 7'b1101010; "N": char_to_segments = 7'b1001000;
                "O": char_to_segments = 7'b1000000; "P": char_to_segments = 7'b0001100;
                "Q": char_to_segments = 7'b0011000; "R": char_to_segments = 7'b1001100;
                "S": char_to_segments = 7'b0010010; "T": char_to_segments = 7'b0000111;
                "U": char_to_segments = 7'b1000001; "V": char_to_segments = 7'b1100011;// 0101110
                "X": char_to_segments = 7'b0001001; "Y": char_to_segments = 7'b0010001;

                // Caracteres especiais
                " ": char_to_segments = 7'b1111111; // Apagado
                default: char_to_segments = 7'b1111111; // Caracter desconhecido = Apagado
            endcase
        end
    endfunction

    // Liga a janela de texto de 6 caracteres aos displays físicos
    assign HEX5 = char_to_segments(text_data[text_pointer + 0]);
    assign HEX4 = char_to_segments(text_data[text_pointer + 1]);
    assign HEX3 = char_to_segments(text_data[text_pointer + 2]);
    assign HEX2 = char_to_segments(text_data[text_pointer + 3]);
    assign HEX1 = char_to_segments(text_data[text_pointer + 4]);
    assign HEX0 = char_to_segments(text_data[text_pointer + 5]);

endmodule