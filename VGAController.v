module VGAController(
    input           pclk,
    input           reset,
    output reg      h_sync,
    output reg      v_sync,
    output          video_on,
    output  [15:0]  read_addr
);
    // Parâmetros para 640x480 @ 60Hz
    localparam H_DISPLAY=640, H_FP=16, H_SP=96, H_BP=48, H_TOTAL=800;
    localparam V_DISPLAY=480, V_FP=10, V_SP=2,  V_BP=33, V_TOTAL=525;

    // Tamanho da imagem de saída (pode variar, usamos o maior possível)
    localparam IMG_WIDTH_OUT = 320;
    localparam IMG_HEIGHT_OUT = 240;

    // Contadores para varrimento do ecrã
    reg [9:0] h_count, v_count;
    always @(posedge pclk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count < H_TOTAL - 1)
                h_count <= h_count + 1;
            else begin
                h_count <= 0;
                if (v_count < V_TOTAL - 1)
                    v_count <= v_count + 1;
                else
                    v_count <= 0;
            end
        end
    end

    // Geração dos sinais de sincronismo
    always @(posedge pclk) begin
        h_sync <= !((h_count >= H_DISPLAY + H_FP) && (h_count < H_DISPLAY + H_FP + H_SP));
        v_sync <= !((v_count >= V_DISPLAY + V_FP) && (v_count < V_DISPLAY + V_FP + V_SP));
    end

    // Sinal de área visível e cálculo do endereço de leitura
    wire is_in_display_area = (h_count < IMG_WIDTH_OUT) && (v_count < IMG_HEIGHT_OUT);
    assign video_on = is_in_display_area;
    assign read_addr = is_in_display_area ? (v_count * IMG_WIDTH_OUT) + h_count : 0;

endmodule