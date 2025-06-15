module multi_cycle_Controller (
    input clk,
    input reset,
    input [3:0] Cond,         // Instruction condition
    input [1:0] OP,           // Bits [27:26] of instruction
    input [5:0] Funct,        // Bits [25:20]
    input Zero_bit,     // {N,Z,C,V}
    input [3:0] Rd,

    output reg IR_write_enable,
    output reg pc_write_enable,
    output reg MemWrite,
    output reg reg_file_write_enable,
    output reg address_select,
    output reg ALUsrcA,
    output reg shifter_input_select,
    output reg shifter_type_select,
    output reg shifter_amount_select,
    output reg [1:0] ALUsrcB,
    output reg [1:0] RegSrc,
    output reg [1:0] ImmSrc,
    output reg [1:0] result_mux_select,
    output reg [3:0] Alu_operation_select,
    output reg Imm_Signal,
    output reg dest_selectR14,
    
    output reg [3:0] state_out
);


    reg CondEx;
    reg ALUOp;
    reg RegW;
    reg MemW;
    reg NextPC;
    reg Branch;
    reg [1:0] Flags;

    wire zero;

    //ALU Decoder
    always @(*) begin
        case(ALUOp)
        1'b1: begin //Data Processing
                case (Funct[4:1])
                    4'b0100: begin
                        Alu_operation_select = 4'b0100; // ADD
                            
                        end
                        4'b0010: Alu_operation_select = 4'b0010; // SUB
                        4'b0000: Alu_operation_select = 4'b0000; // AND
                        4'b1100: Alu_operation_select = 4'b1100; // ORR
                        4'b1010: begin // CMP
                            Alu_operation_select = 4'b0010;
                            Flags = 2'b11;
                        end
                        4'b1101: begin // MOV     
                            Alu_operation_select = 4'b1101;
                        
                        end

                    
                    endcase



        end
        1'b0: begin // Memory
            Alu_operation_select = 4'b0100; //addition



        end
        default Alu_operation_select = 4'b0100;
        endcase

    end

    // INSTR Decoder


    always @(*)begin
        ImmSrc = 2'b00;
        RegSrc = 2'b00;

        case(OP)
        2'b00 : begin
            ImmSrc = 2'b00;
            if (Funct[5]) begin
                RegSrc = 2'b00;
            end else begin
                RegSrc = 2'b00;
            end


        end


        2'b01: begin
            ImmSrc = 2'b01;
            if (Funct[0]) begin
                RegSrc = 2'b00;
            end else begin
                RegSrc = 2'b10;
            end

        end

        2'b10: begin

            ImmSrc = 2'b10;
            RegSrc = 2'b01;

        end

        endcase



    end

    //Conditional logic for controller
    



    

    Register_rsten #(1) Flags3_2 (
        .clk(clk),
        .reset(reset),
        .we(Flags[1]),
        .DATA(Zero_bit),
        .OUT(zero)
    );
    


    
    always @(*) begin
        CondEx = 0;
        case (Cond)
            4'b0000: CondEx = zero;               // EQ: equal
            4'b0001: CondEx = ~zero;              // NE: not equal

            4'b1110: CondEx = 1;               // AL: always
            default: CondEx = 1;               // always
        endcase
    end

    reg cond_ex;

    Register_simple #(.WIDTH(1)) Cond_ex(
        .clk(clk),
        .DATA(CondEx),
        .OUT(cond_ex)


    );
    


    typedef enum reg [3:0] {
        FETCH = 4'd0,
        DECODE = 4'd1,

        EXEC_DP = 4'd2,
        WB_ALU = 4'd3,

        EXEC_MEM = 4'd4,
        MEM_RD = 4'd5,
        WB_MEM = 4'd6,
        MEM_WR = 4'd7,

        EXEC_BRANCH = 4'd8,
        EXEC_BX = 4'd9
        

        
    } state_t;

    state_t state, next_state;

    wire isDP = (OP == 2'b00);       // Data-processing
    wire isMEM = (OP == 2'b01);      // LDR, STR
    wire isBR = (OP == 2'b10);       // B, BL, BX

    wire cmp_instr = isDP && (Funct[4:1] == 4'b1010);  // CMP = SUB + flags, but no writeback
    wire mov_instr = isDP && (Funct[5:1] == 5'b11010);  // MOV
    wire add_instr = isDP && (Funct[5:1] == 5'b01000);  // ADD
    wire sub_instr = isDP && (Funct[5:1] == 5'b00100);  // SUB

    wire isSTR = isMEM && ~Funct[0];  // Funct[0] = L bit: 1 for LDR, 0 for STR
    wire isLDR = isMEM && Funct[0];

    wire isBX  = isDP && (Funct[5:0] == 6'b010010);  // BX
    wire isBL  = isBR && (Funct[4] == 1'b1);         // BL has Link bit set

    // --- FSM state register ---
    initial begin
        state <= FETCH;
        next_state <= FETCH;
    end
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= FETCH;
        else
            state <= next_state;
    end

    assign state_out = state;

    // --- Next state logic ---
    always @(*) begin
        case (state)
            FETCH:       next_state = DECODE;
            DECODE: begin
                if (isDP) begin
                    if (isBX) begin 
                        next_state = EXEC_BX;
                    end else next_state = EXEC_DP;
                end else if (isMEM) begin
                    next_state = EXEC_MEM;
                end else if (isBR) begin
                    next_state = EXEC_BRANCH;
                end else begin
                    next_state = FETCH;
                end
            end
            EXEC_DP:     next_state = WB_ALU;
            WB_ALU:      next_state = FETCH;

            

            EXEC_MEM: begin
                if (isLDR) next_state = MEM_RD;
                else       next_state = MEM_WR;
            end
            MEM_RD:      next_state = WB_MEM;
            WB_MEM:      next_state = FETCH;
            MEM_WR:      next_state = FETCH;

            EXEC_BRANCH: next_state = FETCH;
            EXEC_BX: next_state = FETCH;
            

            default:     next_state = FETCH;
        endcase
    end
    wire PCS = ((Rd == 4'b1111) && RegW ) || Branch;

    
    assign reg_file_write_enable = RegW & cond_ex ;
    assign memory_write_enable = MemW & cond_ex;
    assign pc_write_enable =  (PCS & cond_ex) | NextPC;

    // --- Control signals default ---
    always @(*) begin
        // Defaults (everything off unless needed)
        IR_write_enable = 0;
        
        Branch = 0;
        NextPC = 0;
        MemW = 0;
        RegW = 0;
        address_select = 0;
        ALUsrcA = 0;
        ALUsrcB = 2'b00;
        
        result_mux_select = 2'b00;
        

        shifter_input_select = 0;
        shifter_type_select = 0;
        shifter_amount_select = 0;
        dest_selectR14 = 0;
        
        ALUOp= 0;
        Flags = 2'b00;

        case (state)
            FETCH: begin
                IR_write_enable = 1;
                NextPC = 1;
                address_select = 0;           // PC to memory
                ALUsrcA = 1;          // PC
                ALUsrcB = 2'b10;      // +4
                ALUOp= 0;
                result_mux_select = 2'b10;    // ALUResult
            end

            DECODE: begin
                ALUOp = 0;
                ALUsrcA = 1;          // RD1
                ALUsrcB = 2'b10;      // Shifted operand or Immediate
                result_mux_select = 2'b10; // For address calc or flag prep
            end

            EXEC_DP: begin
                shifter_input_select = Funct[5];
                shifter_type_select = Funct[5];
                shifter_amount_select = Funct[5];
                ALUsrcA = 0;           // RD1
                ALUsrcB = 2'b00;       // RD2 or Immediate
                ALUOp= 1;
                if (cmp_instr) begin
                    RegW=0;
                    Flags = 2'b11;
                end


                //Alu_operation_select = Funct[4:1]; // Map bits to ADD, SUB, etc.
            end

            

            WB_ALU: begin
                RegW = 1;
                if (cmp_instr) begin
                    RegW=0;
                    Flags = 2'b11;
                    ALUOp= 1;
                end
                result_mux_select = 2'b00; // ALUOut
                
                
                
            end

            EXEC_MEM: begin
                shifter_input_select = ~Funct[5];
                shifter_type_select = ~Funct[5];
                shifter_amount_select = ~Funct[5];
                ALUsrcA = 0;           // Base register (RD1)
                if (Funct[5]) begin
                    ALUsrcB = 2'b00;
                end else begin
                    ALUsrcB = 2'b01;
                end

                // Offset
                ALUOp= 0;
                //Alu_operation_select = 4'b0000;  // ADD
            end

            MEM_RD: begin
                address_select = 1;           // ALUOut to memory
                result_mux_select = 2'b00;
                // Read is implicit
            end

            WB_MEM: begin
                RegW = 1;
                result_mux_select = 2'b01;    // Memory data
            end

            MEM_WR: begin
                address_select = 1;
                MemW = 1;
            end

            EXEC_BRANCH: begin
                ALUsrcA = 0;
                ALUsrcB = 2'b01;      // Immediate offset
                //Alu_operation_select = 4'b0000; // ADD
                result_mux_select = 2'b10;
                Branch = 1;
                if (isBL) begin
                    dest_selectR14 = 1;
                    RegW = 1;
                end
                

                
                
            end

            EXEC_BX: begin
                
                result_mux_select = 2'b11;    // Choose RD1 (Rm) to go to PC
                Branch = 1;              // Enable PC write



            end



            

        endcase
    end


endmodule