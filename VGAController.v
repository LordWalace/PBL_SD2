module VGAController(
    input           pclk,
    input           reset,
    input   [2:0]   zoom_level,
    output reg      h_sync,
    output reg      v_sync,
    output          video_on,
    output          [16:0]  read_addr
);

    // --- Parâmetros de Temporização para 640x480 @ 60 Hz ---
    localparam H_DISPLAY=640, H_FP=16, H_SP=96, H_BP=48, H_TOTAL=800;
    localparam V_DISPLAY=480, V_FP=10, V_SP=2,  V_BP=33, V_TOTAL=525;
    
    // --- Registadores e Fios ---
    reg [9:0] h_count, v_count;
    wire [9:0] IMG_WIDTH_OUT, IMG_HEIGHT_OUT;
    wire [9:0] H_OFFSET, V_OFFSET;
    wire is_image_area;

    // --- Lógica Sequencial: Contadores de Varredura ---
    always @(posedge pclk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count < H_TOTAL - 1) begin
                h_count <= h_count + 1;
            end else begin
                h_count <= 0;
                if (v_count < V_TOTAL - 1) begin
                    v_count <= v_count + 1;
                end else begin
                    v_count <= 0;
                end
            end
        end
    end

    // --- Lógica Combinacional: Centralização da Imagem ---
    assign IMG_WIDTH_OUT = (zoom_level == 3'd4) ? 640 :
                           (zoom_level == 3'd3) ? 320 :
                           (zoom_level == 3'd2) ? 160 :
                           (zoom_level == 3'd1) ? 80  : 40;

    assign IMG_HEIGHT_OUT = (zoom_level == 3'd4) ? 480 :
                            (zoom_level == 3'd3) ? 240 :
                            (zoom_level == 3'd2) ? 120 :
                            (zoom_level == 3'd1) ? 60  : 30;

    assign H_OFFSET = (H_DISPLAY - IMG_WIDTH_OUT) / 2;
    assign V_OFFSET = (V_DISPLAY - IMG_HEIGHT_OUT) / 2;
    assign is_image_area = (h_count >= H_OFFSET) && (h_count < H_OFFSET + IMG_WIDTH_OUT) &&
                         (v_count >= V_OFFSET) && (v_count < V_OFFSET + IMG_HEIGHT_OUT);
    
    assign video_on = is_image_area;
    assign read_addr = is_image_area ? ((v_count - V_OFFSET) * IMG_WIDTH_OUT) + (h_count - H_OFFSET) : 0;

    // --- Lógica Combinacional: Sinais de Sincronismo ---
    always @(*) begin
        h_sync = !((h_count >= H_DISPLAY + H_FP) && (h_count < H_DISPLAY + H_FP + H_SP));
        v_sync = !((v_count >= V_DISPLAY + V_FP) && (v_count < V_DISPLAY + V_FP + V_SP));
    end

endmodule