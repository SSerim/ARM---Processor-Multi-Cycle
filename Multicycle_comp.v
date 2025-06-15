module multi_cycle_computer(
    input clk,
    input reset,
    input [3:0] debug_reg_select,
    output [31:0] debug_reg_out,
    output [31:0] fetchPC,
    output [3:0] fsm_state
);

    // Internal wires to connect controller and datapath
    wire pc_write_enable;
    wire address_select;
    wire memory_write_enable;
    wire IR_write_enable;
    wire reg_file_write_enable;
    wire ALUsrcA;
    wire shifter_input_select;
    wire shifter_type_select;
    wire shifter_amount_select;
    wire dest_selectR14;
    wire [1:0] ALUsrcB;
    wire [1:0] RegSrc;
    wire [1:0] ImmSrc;
    wire [1:0] result_mux_select;
    wire [3:0] Alu_operation_select;

    wire [3:0] Cond, Rd;
    wire [1:0] Op;
    wire [5:0] Funct;
    wire Zero_bit;
    wire Imm_Signal;

    // Datapath instantiation
    multicycle_datapath my_datapath (
        .clk(clk),
        .reset(reset),
        .DEBUG_IN(debug_reg_select),

        .pc_write_enable(pc_write_enable),
        .address_select(address_select),
        .memory_write_enable(memory_write_enable),
        .IR_write_enable(IR_write_enable),
        .reg_file_write_enable(reg_file_write_enable),
        .ALUsrcA(ALUsrcA),
        .shifter_input_select(shifter_input_select),
        .shifter_type_select(shifter_type_select),
        .shifter_amount_select(shifter_amount_select),
        .dest_selectR14(dest_selectR14),
        .ALUsrcB(ALUsrcB),
        .RegSrc(RegSrc),
        .ImmSrc(ImmSrc),
        .result_mux_select(result_mux_select),
        .Alu_operation_select(Alu_operation_select),

        .Cond(Cond),
        .Op(Op),
        .Funct(Funct),
        .Rd(Rd),
        .Zero_bit(Zero_bit),

        .DEBUG_OUT(debug_reg_out),
        .PC(fetchPC)
    );

    // Controller instantiation
    multi_cycle_Controller my_controller (
        .clk(clk),
        .reset(reset),
        .Cond(Cond),
        .OP(Op),
        .Funct(Funct),
        .Zero_bit(Zero_bit),
        .Rd(Rd),

        .IR_write_enable(IR_write_enable),
        .pc_write_enable(pc_write_enable),
        .memory_write_enable(memory_write_enable),
        .reg_file_write_enable(reg_file_write_enable),
        .address_select(address_select),
        .ALUsrcA(ALUsrcA),
        .shifter_input_select(shifter_input_select),
        .shifter_type_select(shifter_type_select),
        .shifter_amount_select(shifter_amount_select),
        .ALUsrcB(ALUsrcB),
        .RegSrc(RegSrc),
        .ImmSrc(ImmSrc),
        .result_mux_select(result_mux_select),
        .Alu_operation_select(Alu_operation_select),
        .dest_selectR14(dest_selectR14),

        .state_out(fsm_state)
    );

endmodule
