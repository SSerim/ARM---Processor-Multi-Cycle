module multicycle_datapath(
    input clk,
    input reset,
    //debug inputs
    input [3:0] DEBUG_IN,
    //control signals
    input pc_write_enable,
    input address_select,
    input memory_write_enable,
    input IR_write_enable,
    input reg_file_write_enable,
    input ALUsrcA,
    input shifter_input_select,
    input shifter_type_select,
    input shifter_amount_select,
    input dest_selectR14,
    input [1:0] ALUsrcB,
    input [1:0] RegSrc,
    input [1:0] ImmSrc,
    input [1:0] result_mux_select,
    input [3:0] Alu_operation_select,
    //Controller inputs
    output [3:0] Cond,
    output [1:0] Op,
    output [5:0] Funct,
    output [3:0] Rd,
    output Zero_bit,
    //debug outputs
    output [31:0] DEBUG_OUT,
    output [31:0] PC
);
assign PC = PC_out;
//wire declarations to connect the components
wire [31:0] PC_out;
wire [31:0] resultante;
wire [31:0] Adr;
wire [31:0] Read_data_or_instruction;
wire [31:0] instruction;
wire [31:0] RD1;
wire [31:0] RD2;
wire [31:0] Extended_output;
wire [31:0] RD1_out;
wire [31:0] RD2_out;
wire [31:0] SrcA;
wire [31:0] SrcB;
wire [31:0] ALU_result;
wire [31:0] ALU_Out;
wire [31:0] Data_out;
wire [3:0] RA_1;
wire [3:0] RA_2;

// Control signals
assign Cond = instruction[31:28];
assign Op = instruction[27:26];
assign Funct = instruction[25:20];
assign Rd = instruction[15:12];

// PC register
Register_rsten_neg #(.WIDTH(32)) Prog_counter(
    .clk(clk),
    .reset(reset),  
    .we(pc_write_enable),
    .DATA(Data_out),
    .OUT(PC_out)
);

// Mux for PC ---- address of memory input
Mux_2to1 #(.WIDTH(32)) Mux_PC(
    .select(address_select),
    .input_0(PC_out),
    .input_1(resultante),
    .output_value(Adr)
);

// Memory module
ID_memory #(.BYTE_SIZE(4), .ADDR_WIDTH(32)) Memory(
    .clk(clk),
    .WE(memory_write_enable),
    .ADDR(Adr),
    .WD(RD2_out),
    .RD(Read_data_or_instruction)
);

// Instruction register
Register_en #(.WIDTH(32)) Instruction_reg(
    .clk(clk),
    .en(IR_write_enable),
    .DATA(Read_data_or_instruction),
    .OUT(instruction)
);

// Data register
Register_simple #(.WIDTH(32)) Data_reg(
    .clk(clk),
    .DATA(Read_data_or_instruction),
    .OUT(Data_out)
);

//Mux of RA1
Mux_2to1 #(.WIDTH(4)) Mux_RA1(
    .select(RegSrc[1]),
    .input_0(instruction[19:16]),
    .input_1(4'b1111),
    .output_value(RA_1)
);

//Mux of RA2
Mux_2to1 #(.WIDTH(4)) Mux_RA2(
    .select(RegSrc[0]),
    .input_0(instruction[3:0]),
    .input_1(instruction[15:12]),
    .output_value(RA_2)
);
//Mux of destination reg file
wire [3:0]A3;
Mux_2to1 #(.WIDTH(4)) Mux_R14(
    .select(dest_selectR14),
    .input_0(instruction[15:12]),
    .input_1(4'b1110),
    .output_value(A3)
);
// Register File module

Register_file #(.WIDTH(32)) Reg_file(
    .clk(clk),
    .write_enable(reg_file_write_enable),
    .reset(reset),
    .Source_select_0(RA_1),
    .Source_select_1(RA_2),
    .Debug_Source_select(DEBUG_IN),
    .Destination_select(A3),
    .DATA(resultante),      //burası değişecek yüksek ihtimalle
    .Reg_15(resultante),
    .out_0(RD1),
    .out_1(RD2),
    .Debug_out(DEBUG_OUT)
);


//Immediate Extender module
Extender Immediate_extender(
    .Extended_data(Extended_output),
    .DATA(instruction[23:0]),
    .select(ImmSrc)
);

// Rd and Rn registers
Register_simple #(32) RD1_register(
    .clk(clk),
    .DATA(RD1),
    .OUT(RD1_out)
);

Register_simple #(32) RD2_register(
    .clk(clk),
    .DATA(RD2),
    .OUT(RD2_out)
);
wire [31:0] shifter_inp;
//Mux of Shifter Input
Mux_2to1 #(.WIDTH(32)) Mux_Shifter_input(
    .select(shifter_input_select),
    .input_0(RD2_out),
    .input_1(Extended_output),
    .output_value(shifter_inp)
);
//Mux of Shifter type select
wire [1:0] shifter_type;
Mux_2to1 #(.WIDTH(2)) Mux_Shifter_type(
    .select(shifter_type_select),
    .input_0(instruction[6:5]),
    .input_1(2'b11),
    .output_value(shifter_type)
);
// Shifter amount select
wire [4:0] shifter_amount;
Mux_2to1 #(.WIDTH(5)) Mux_Shifter_amount(
    .select(shifter_amount_select),
    .input_0(instruction[11:7]),
    .input_1(5'b00001),
    .output_value(shifter_amount)
);


//Shifter module
wire [31:0] shifter_output;
shifter #(.WIDTH(32)) Shifter_baba(
    .control(shifter_type),
    .shamt(shifter_amount),
    .DATA(shifter_inp),
    .OUT(shifter_output)
);
//Mux of ALU Source A
Mux_2to1 #(.WIDTH(32)) Mux_Source_A(
    .select(ALUsrcA),
    .input_0(RD1_out),
    .input_1(PC_out),
    .output_value(SrcA)
);

//Mux of ALU Source B
Mux_4to1 #(.WIDTH(32)) Mux_Source_B(
    .select(ALUsrcB),
    .input_0(shifter_output),
    .input_1(Extended_output),
    .input_2(32'd4),
    .input_3(),
    .output_value(SrcB)
);

//ALU baba
ALU #(.WIDTH(32)) ALU_baba(
	.control(Alu_operation_select),
	.CI(1'b0),
	.DATA_A(SrcA),
	.DATA_B(SrcB),
    .OUT(ALU_result),
	.CO(),
	.OVF(),
	.N(), 
    .Z(Zero_bit)
    );

// ALU result register

Register_simple #(32) ALU_reg(
    .clk(clk),
    .DATA(ALU_result),
    .OUT(ALU_Out)
);

// Mux for result
Mux_4to1 #(.WIDTH(32)) result_mux(
    .select(result_mux_select),
    .input_0(ALU_Out),
    .input_1(Data_out),
    .input_2(ALU_result),
    .input_3(),
    .output_value(resultante)
);
endmodule