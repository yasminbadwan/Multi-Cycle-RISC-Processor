// ============================================================
// Multicycle RISC Processor  -  Top Level
// ============================================================
// This file connects ALL the sub-modules together to build
// the complete multicycle processor.
//
// PIPELINE REGISTERS (key to multicycle operation):
//   IR     = stores the fetched instruction for stages ID/EX/MEM/WB
//   A      = stores Reg[rs] value after ID stage
//   B      = stores Reg[rt] value after ID stage
//   ALUOut = stores ALU result after EX stage
//   MDR    = stores memory read result after MEM stage
//   PCsave = stores PC value during ID (for JAL return address)
//
// HOW IT WORKS (example: ADD R3, R1, R2):
//   Cycle 1 (IF) : IR = Mem[PC],  PC = PC+1
//   Cycle 2 (ID) : A = Reg[R1],  B = Reg[R2]
//   Cycle 3 (EX) : ALUOut = A + B = R1 + R2
//   Cycle 4 (WB) : Reg[R3] = ALUOut
// ============================================================

`timescale 1ns/1ps

module processor(
    input wire clk,   // clock signal
    input wire rst    // reset: 1=reset (active HIGH), 0=run
);

    // ============================================================
    // Pipeline registers (hold values between stages)
    // ============================================================
    reg [31:0] IR;      // Instruction Register
    reg [31:0] A;       // holds Reg[rs] after ID
    reg [31:0] B;       // holds Reg[rt] after ID
    reg [31:0] ALUOut;  // holds ALU result after EX
    reg [31:0] MDR;     // Memory Data Register (holds loaded data after MEM)
    reg [31:0] PCsave;  // holds PC during ID (used by JAL for return address)

    // ============================================================
    // Wires that connect all modules
    // ============================================================

    // Program Counter
    wire [31:0] pc;        // current PC value
    wire [31:0] next_pc;   // next PC value (chosen by mux)
    wire        pc_update; // 1 = allow PC to update this clock cycle

    // Instruction memory output
    wire [31:0] instruction_out;  // raw instruction read from memory

    // Decoded fields from the Instruction Register (IR)
    wire [5:0]  opcode;
    wire [3:0]  rd, rs, rt;
    wire [17:0] immediate;
    wire [25:0] offset;

    // Control signals from the FSM
    wire [1:0]  PCSrc;
    wire [1:0]  RegDst;
    wire        RegWr;
    wire        ExtOp;
    wire        ExtSel;
    wire        ALUSrc;
    wire [3:0]  ALUOp;
    wire        MemRd;
    wire        MemWr;
    wire [1:0]  WBData;
    wire        IRWrite;
    wire        AWrite;
    wire        BWrite;
    wire        ALUOutWrite;
    wire        MDRWrite;
    wire [2:0]  State;    // current stage (0=IF 1=ID 2=EX 3=MEM 4=WB)

    // Register file read outputs
    wire [31:0] BusA;  // value of Reg[rs]
    wire [31:0] BusB;  // value of Reg[rt]

    // Extender output
    wire [31:0] Imm32;

    // ALU outputs
    wire [31:0] alu_result;
    wire        zero;         // 1 when alu_result = 0

    // Data memory output
    wire [31:0] mem_data_out;

    // ============================================================
    // MODULE 1: Instruction Decoder
    // Breaks IR into: opcode, rd, rs, rt, immediate, offset
    // The decoder reads from IR (the pipeline register), NOT from
    // instruction_out directly, so the fields are stable across
    // all stages of the same instruction.
    // ============================================================
    instruction_decoder decoder(
        .instruction(IR),
        .opcode(opcode),
        .rd(rd),
        .rs(rs),
        .rt(rt),
        .immediate(immediate),
        .offset(offset)
    );

    // ============================================================
    // MODULE 2: FSM Control Unit
    // Reads: Opcode + Zero flag
    // Outputs: all control signals for every other module
    // ============================================================
    C control_fsm(
        .clk(clk),
        .rst(rst),
        .Opcode(opcode),
        .Zero(zero),
        .PCSrc(PCSrc),
        .RegDst(RegDst),
        .RegWr(RegWr),
        .ExtOp(ExtOp),
        .ExtSel(ExtSel),
        .ALUSrc(ALUSrc),
        .ALUOp(ALUOp),
        .MemRd(MemRd),
        .MemWr(MemWr),
        .WBData(WBData),
        .IRWrite(IRWrite),
        .AWrite(AWrite),
        .BWrite(BWrite),
        .ALUOutWrite(ALUOutWrite),
        .MDRWrite(MDRWrite),
        .State(State)
    );

    // ============================================================
    // MODULE 3: Extender
    // Stretches the immediate value from 18 or 26 bits to 32 bits.
    //   ExtSel=0 -> use 18-bit I-type immediate
    //   ExtSel=1 -> use 26-bit J-type offset
    //   ExtOp=0  -> zero extend (fill with 0s on the left)
    //   ExtOp=1  -> sign extend (copy sign bit to fill)
    // ============================================================
    Extender extender(
        .in(offset),     // 26-bit input (instruction[25:0])
        .extsel(ExtSel),
        .extop(ExtOp),
        .Imm32(Imm32)    // 32-bit output
    );

    // ============================================================
    // MODULE 4: Program Counter
    //
    // next_pc mux (controlled by PCSrc):
    //   00 -> PC + 1      (normal: go to next instruction)
    //   01 -> PC + Imm32  (branch: jump relative to current PC)
    //   10 -> Imm32       (jump: go to absolute address)
    //   11 -> A           (JR: go to address in Reg[rs])
    //
    // pc_update = 1 allows PC to take the new value on next edge.
    // PC updates during IF (always) or when branch/jump happens.
    // ============================================================
    assign next_pc =
        (PCSrc == 2'b00) ? pc + 32'd1 :
        (PCSrc == 2'b01) ? pc + Imm32 :
        (PCSrc == 2'b10) ? Imm32      :
                           A;           // PCSrc == 2'b11 (JR)

    assign pc_update = IRWrite | PCSrc[0] | PCSrc[1];

    PC pc_module(
        .clk(clk),
        .reset(~rst),       // PC module uses active-LOW reset, so we invert rst
        .pcupdate(pc_update),
        .nextpc(next_pc),
        .pc(pc)
    );

    // ============================================================
    // MODULE 5: Instruction Memory
    // Reads instruction from address pc.
    // This is a READ-ONLY combinational (instant) read.
    // ============================================================
    instruction_memory imem(
        .Address(pc),
        .Instruction(instruction_out)
    );

    // IR pipeline register: captures instruction at end of IF stage
    always @(posedge clk or posedge rst) begin
        if (rst)           IR <= 32'b0;
        else if (IRWrite)  IR <= instruction_out;
    end

    // ============================================================
    // MODULE 6: Register File
    // Has 16 registers (R0 always = 0).
    // Reads are instant (combinational).
    // Writes happen on the clock edge in WB stage when RegWr=1.
    // ============================================================

    // Write-address mux: which register to write back to?
    //   RegDst 00/01 -> rd field from instruction
    //   RegDst 10    -> R14 (JAL stores return address in R14)
    wire [3:0] reg_write_addr;
    assign reg_write_addr = (RegDst == 2'b10) ? 4'd14 : rd;

    // Write-data mux: what value to write back?
    //   WBData 00 -> ALUOut  (R-type or I-type ALU result)
    //   WBData 01 -> MDR     (data loaded from memory by LW)
    //   WBData 10 -> PCsave  (r eturn address, used by JAL)
    //   WBData 11 -> 0       (CLR: write zero to register)
    wire [31:0] reg_write_data;
    assign reg_write_data =
        (WBData == 2'b00) ? ALUOut :
        (WBData == 2'b01) ? MDR    :
        (WBData == 2'b10) ? PCsave :
                            32'b0;

    Registers reg_file(
        .clk(clk),
        .reset(rst),
        .RegWrite(RegWr),
        .RA(rs),               // read Reg[rs] -> BusA
        .RB(rt),               // read Reg[rt] -> BusB
        .RW(reg_write_addr),   // write destination register
        .BusW(reg_write_data), // write data
        .BusA(BusA),
        .BusB(BusB)
    );

    // A, B, PCsave pipeline registers: captured at end of ID stage
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            A      <= 32'b0;
            B      <= 32'b0;
            PCsave <= 32'b0;
        end else begin
            if (AWrite) begin
                A      <= BusA;  // save Reg[rs]
                PCsave <= pc;    // save PC for JAL (pc is already PC+1 after IF)
            end
            if (BWrite)
                B <= BusB;       // save Reg[rt]
        end
    end

    // ============================================================
    // MODULE 7: ALU
    // A is always from pipeline register A (= Reg[rs]).
    // B input is chosen by ALUSrc:
    //   ALUSrc=0 -> use pipeline register B (= Reg[rt])
    //   ALUSrc=1 -> use Imm32 (immediate value)
    // ============================================================
    wire [31:0] alu_b;
    assign alu_b = (ALUSrc) ? Imm32 : B;

    ALU alu(
        .aluop(ALUOp),
        .A(A),
        .B(alu_b),
        .aluresult(alu_result)
    );

    // zero flag: 1 when ALU result is exactly zero
    assign zero = (alu_result == 32'b0) ? 1'b1 : 1'b0;

    // ALUOut pipeline register: captured at end of EX stage
    always @(posedge clk or posedge rst) begin
        if (rst)             ALUOut <= 32'b0;
        else if (ALUOutWrite) ALUOut <= alu_result;
    end

    // ============================================================
    // MODULE 8: Data Memory
    // Only used in MEM stage (LW, SW, SWAP instructions).
    // Address  = ALUOut (base + offset, computed in EX)
    // Data_in  = B     (= Reg[rt], the value to store for SW)
    // ============================================================
    data_memory dmem(
        .Clk(clk),
        .Address(ALUOut),
        .Data_in(B),
        .MemWrite(MemWr),
        .MemRead(MemRd),
        .Data_out(mem_data_out)
    );

    // MDR pipeline register: captured at end of MEM stage
    always @(posedge clk or posedge rst) begin
        if (rst)          MDR <= 32'b0;
        else if (MDRWrite) MDR <= mem_data_out;
    end

endmodule


// ============================================================
// Testbench for the Multicycle Processor
// ============================================================
// Test program loaded from program.mem:
//
//   Instr 0: ADDI R1, R0, 5   -> R1 = 0 + 5 = 5    (takes 4 cycles: IF ID EX WB)
//   Instr 1: ADD  R3, R1, R2  -> R3 = 5 + 0 = 5    (takes 4 cycles: IF ID EX WB)
//   Instr 2: ADDI R2, R0, 7   -> R2 = 0 + 7 = 7    (takes 4 cycles: IF ID EX WB)
//   Instr 3: ADD  R3, R1, R2  -> R3 = 5 + 7 = 12   (takes 4 cycles: IF ID EX WB)
//
// Expected final values: R1=5, R2=7, R3=12
// Total cycles needed: 4+4+4+4 = 16 cycles (we run 30 to be safe)
// ============================================================

`timescale 1ns/1ps

module processor_tb;

    reg clk, rst;

    // Connect the processor
    processor uut(.clk(clk), .rst(rst));

    // Clock: 10 ns period (toggle every 5 ns)
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    integer cycle;

    // Print processor state every clock cycle (after signals settle)
    always @(posedge clk) begin
        #1;  // wait 1 ns for outputs to settle
        if (!rst) begin
            $display("Cycle %02d | Stage=%0d | PC=%02d | OP=%02d | A=%4d | B=%4d | ALUOut=%4d | MDR=%4d",
                cycle,
                uut.State,
                uut.pc,
                uut.opcode,
                $signed(uut.A),
                $signed(uut.B),
                $signed(uut.ALUOut),
                $signed(uut.MDR)
            );
        end
        cycle = cycle + 1;
    end

    initial begin
        $dumpfile("wave.vcd");     // save waveforms for GTKWave / ActiveHDL
        $dumpvars(0, processor_tb);

        // Initialize
        cycle = 0;
        rst   = 1'b1;    // start in reset

        // Hold reset for 2 full clock cycles
        @(posedge clk); #1;
        @(posedge clk); #1;

        // Release reset -> processor begins executing from PC=0
        rst = 1'b0;
        $display("=== PROCESSOR STARTED (reset released) ===");
        $display("Cycle ## | Stage | PC | OP | A | B | ALUOut | MDR");
        $display("(Stage: 0=IF  1=ID  2=EX  3=MEM  4=WB)");

        // Run for 30 cycles (only need 16 for our 4-instruction test)
        repeat(30) @(posedge clk);
        #1;

        // Check final register values
        $display("=== FINAL REGISTER VALUES ===");
        $display("R1 = %0d  (expected 5)",  uut.reg_file.registers[1]);
        $display("R2 = %0d  (expected 7)",  uut.reg_file.registers[2]);
        $display("R3 = %0d  (expected 12)", uut.reg_file.registers[3]);

        if (uut.reg_file.registers[1] == 32'd5)
            $display("[PASS] R1 = 5");
        else
            $display("[FAIL] R1 wrong: got %0d", uut.reg_file.registers[1]);

        if (uut.reg_file.registers[2] == 32'd7)
            $display("[PASS] R2 = 7");
        else
            $display("[FAIL] R2 wrong: got %0d", uut.reg_file.registers[2]);

        if (uut.reg_file.registers[3] == 32'd12)
            $display("[PASS] R3 = 12");
        else
            $display("[FAIL] R3 wrong: got %0d", uut.reg_file.registers[3]);

        $stop;
    end

endmodule
