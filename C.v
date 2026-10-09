// ============================================================
// Finite State Machine (FSM) Control Unit  --  module C
// ============================================================
// This is the BRAIN of the multicycle processor.
// Every clock cycle the FSM decides which stage we are in
// and outputs the right control signals for every other module.
//
// THE 5 STAGES:
//   IF  (0) = Instruction Fetch   : read instruction, PC = PC+1
//   ID  (1) = Instruction Decode  : read registers A and B
//   EX  (2) = Execute             : ALU works / branch or jump happens
//   MEM (3) = Memory Access       : read or write data memory
//   WB  (4) = Write Back          : write result into register file
//
// CYCLES PER INSTRUCTION:
//   R-type (ADD/SUB/AND/OR/XOR/NOR/SLL/SRL) : IF->ID->EX->WB     = 4 cycles
//   I-type ALU (ADDI/ANDI/ORI)              : IF->ID->EX->WB     = 4 cycles
//   LW, SWAP                                : IF->ID->EX->MEM->WB= 5 cycles
//   SW                                      : IF->ID->EX->MEM    = 4 cycles
//   CLR                                     : IF->ID->WB         = 3 cycles
//   BEQ, BNE, JR                            : IF->ID->EX         = 3 cycles
//   J                                       : IF->ID             = 2 cycles
//   JAL                                     : IF->ID->WB         = 3 cycles
// ============================================================

`timescale 1ns/1ps

module C(
    input  wire       clk,
    input  wire       rst,     // active-HIGH reset (1 = reset)
    input  wire [5:0] Opcode,  // opcode of the current instruction in IR
    input  wire       Zero,    // 1 when ALU result = 0  (used by BEQ/BNE)

    // ---- PC mux select ----
    // 00 = PC+1 (next instruction)
    // 01 = PC + Imm32 (branch, relative)
    // 10 = Imm32 (jump, absolute)
    // 11 = A register (JR)
    output reg [1:0] PCSrc,

    // ---- Register file ----
    output reg [1:0] RegDst,   // 00 or 01 = rd field, 10 = R14 (JAL)
    output reg       RegWr,    // 1 = write result into register

    // ---- Sign/Zero Extender ----
    output reg       ExtOp,    // 0 = zero extend,    1 = sign extend
    output reg       ExtSel,   // 0 = I-type (18-bit), 1 = J-type (26-bit)

    // ---- ALU ----
    output reg       ALUSrc,   // 0 = use Reg[rt] (B),  1 = use Imm32
    output reg [3:0] ALUOp,    // which ALU operation to perform

    // ---- Data Memory ----
    output reg       MemRd,    // 1 = read  from memory this cycle
    output reg       MemWr,    // 1 = write into memory this cycle

    // ---- Write-Back mux ----
    // 00 = ALUOut,  01 = MDR (loaded data),  10 = PCsave (JAL),  11 = 0 (CLR)
    output reg [1:0] WBData,

    // ---- Pipeline register enables ----
    // These signals tell each pipeline register WHEN to capture a new value.
    output reg       IRWrite,      // 1 = latch instruction   into IR
    output reg       AWrite,       // 1 = latch Reg[rs]       into A
    output reg       BWrite,       // 1 = latch Reg[rt]       into B
    output reg       ALUOutWrite,  // 1 = latch alu_result    into ALUOut
    output reg       MDRWrite,     // 1 = latch memory output into MDR

    output reg [2:0] State   // current stage (0=IF 1=ID 2=EX 3=MEM 4=WB)
);

    // ============================================================
    // Instruction opcode constants
    // ============================================================
    localparam ADD  = 6'd0,  SUB  = 6'd1,  AND_ = 6'd2,  OR_  = 6'd3;
    localparam XOR_ = 6'd4,  NOR_ = 6'd5,  SLL  = 6'd6,  SRL  = 6'd7;
    localparam CLR  = 6'd8,  JR   = 6'd9;
    localparam ADDI = 6'd10, ANDI = 6'd11, ORI  = 6'd12;
    localparam LW   = 6'd13, SW   = 6'd14, SWAP = 6'd15;
    localparam BEQ  = 6'd16, BNE  = 6'd17;
    localparam J    = 6'd18, JAL  = 6'd19;

    // Stage number constants
    localparam IF  = 3'd0, ID  = 3'd1, EX  = 3'd2, MEM = 3'd3, WB  = 3'd4;

    // ALU operation codes (must match the numbers in ALU.v)
    localparam ALU_ADD  = 4'd0, ALU_SUB  = 4'd1, ALU_AND  = 4'd2;
    localparam ALU_OR   = 4'd3, ALU_XOR  = 4'd4, ALU_NOR  = 4'd5;
    localparam ALU_SLL  = 4'd6, ALU_SRL  = 4'd7, ALU_ZERO = 4'd8;

    reg [2:0] next_state;  // where the FSM will go on the NEXT clock edge

    // ============================================================
    // STATE REGISTER  (updates on every rising clock edge)
    // ============================================================
    always @(posedge clk or posedge rst) begin
        if (rst) State <= IF;       // reset: always start at IF
        else     State <= next_state;
    end

    // ============================================================
    // NEXT-STATE LOGIC  (pure combinational: decides next stage)
    // ============================================================
    always @(*) begin
        case (State)

            IF: next_state = ID;   // after fetch, always decode

            ID: case (Opcode)
                    ADD, SUB, AND_, OR_, XOR_, NOR_, SLL, SRL,
                    JR, ADDI, ANDI, ORI, LW, SW, SWAP, BEQ, BNE:
                        next_state = EX;    // need ALU -> go to EX
                    CLR, JAL:    next_state = WB;   // skip EX, go write back
                    J:           next_state = IF;   // jump done in ID, fetch next
                    default:     next_state = IF;
                endcase

            EX: case (Opcode)
                    ADD, SUB, AND_, OR_, XOR_, NOR_, SLL, SRL,
                    ADDI, ANDI, ORI:  next_state = WB;   // ALU done, write back
                    LW, SW, SWAP:     next_state = MEM;  // need memory access
                    BEQ, BNE, JR:     next_state = IF;   // done after EX
                    default:          next_state = IF;
                endcase

            MEM: case (Opcode)
                    LW, SWAP:  next_state = WB;   // write loaded value to register
                    SW:        next_state = IF;   // store done, fetch next
                    default:   next_state = IF;
                endcase

            WB:  next_state = IF;   // write back done, fetch next instruction

            default: next_state = IF;
        endcase
    end

    // ============================================================
    // OUTPUT LOGIC  (combinational: what signals to assert each stage)
    // ============================================================
    always @(*) begin
        // ----- Turn EVERYTHING off as default -----
        PCSrc       = 2'b00;
        RegDst      = 2'b00;
        RegWr       = 1'b0;
        ExtOp       = 1'b0;
        ExtSel      = 1'b0;
        ALUSrc      = 1'b0;
        ALUOp       = ALU_ADD;
        MemRd       = 1'b0;
        MemWr       = 1'b0;
        WBData      = 2'b00;
        IRWrite     = 1'b0;
        AWrite      = 1'b0;
        BWrite      = 1'b0;
        ALUOutWrite = 1'b0;
        MDRWrite    = 1'b0;

        case (State)

            // -----------------------------------------------
            // IF: Fetch the instruction at address PC.
            //     PC advances to PC+1 for the next cycle.
            // -----------------------------------------------
            IF: begin
                IRWrite = 1'b1;   // capture instruction into IR
                PCSrc   = 2'b00;  // PC = PC + 1
            end

            // -----------------------------------------------
            // ID: Read two register values.
            //     Also handle J (jump in ID) and JAL.
            // -----------------------------------------------
            ID: begin
                AWrite = 1'b1;  // latch BusA = Reg[rs] into A
                BWrite = 1'b1;  // latch BusB = Reg[rt] into B

                case (Opcode)
                    J: begin
                        PCSrc  = 2'b10;  // PC = jump target
                        ExtSel = 1'b1;   // use 26-bit J-type offset
                    end
                    JAL: begin
                        PCSrc  = 2'b10;  // PC = jump target
                        ExtSel = 1'b1;   // use 26-bit J-type offset
                    end
                    default: PCSrc = 2'b00;
                endcase
            end

            // -----------------------------------------------
            // EX: ALU computes the result.
            //     Branches and JR also update the PC here.
            // -----------------------------------------------
            EX: begin
                case (Opcode)

                    // R-type: ALU(Reg[rs], Reg[rt])
                    ADD:  begin ALUSrc=1'b0; ALUOp=ALU_ADD;  ALUOutWrite=1'b1; end
                    SUB:  begin ALUSrc=1'b0; ALUOp=ALU_SUB;  ALUOutWrite=1'b1; end
                    AND_: begin ALUSrc=1'b0; ALUOp=ALU_AND;  ALUOutWrite=1'b1; end
                    OR_:  begin ALUSrc=1'b0; ALUOp=ALU_OR;   ALUOutWrite=1'b1; end
                    XOR_: begin ALUSrc=1'b0; ALUOp=ALU_XOR;  ALUOutWrite=1'b1; end
                    NOR_: begin ALUSrc=1'b0; ALUOp=ALU_NOR;  ALUOutWrite=1'b1; end
                    SLL:  begin ALUSrc=1'b0; ALUOp=ALU_SLL;  ALUOutWrite=1'b1; end
                    SRL:  begin ALUSrc=1'b0; ALUOp=ALU_SRL;  ALUOutWrite=1'b1; end

                    // I-type ALU: ALU(Reg[rs], sign_extend(imm18))
                    ADDI: begin ExtOp=1'b1; ALUSrc=1'b1; ALUOp=ALU_ADD; ALUOutWrite=1'b1; end
                    ANDI: begin ExtOp=1'b0; ALUSrc=1'b1; ALUOp=ALU_AND; ALUOutWrite=1'b1; end
                    ORI:  begin ExtOp=1'b0; ALUSrc=1'b1; ALUOp=ALU_OR;  ALUOutWrite=1'b1; end

                    // Memory address: address = Reg[rs] + sign_extend(imm18)
                    LW, SW, SWAP: begin
                        ExtOp       = 1'b1;
                        ALUSrc      = 1'b1;
                        ALUOp       = ALU_ADD;
                        ALUOutWrite = 1'b1;  // save computed address in ALUOut
                    end

                    // BEQ: branch if Reg[rs] == Reg[rt]  (i.e. A - B = 0)
                    BEQ: begin
                        ExtOp  = 1'b1;
                        ALUSrc = 1'b0;
                        ALUOp  = ALU_SUB;
                        if (Zero) PCSrc = 2'b01;  // PC = PC + Imm32
                    end

                    // BNE: branch if Reg[rs] != Reg[rt]
                    BNE: begin
                        ExtOp  = 1'b1;
                        ALUSrc = 1'b0;
                        ALUOp  = ALU_SUB;
                        if (!Zero) PCSrc = 2'b01;
                    end

                    // JR: jump to address in Reg[rs]
                    JR: PCSrc = 2'b11;  // PC = A = Reg[rs]

                    default: begin ALUSrc=1'b0; ALUOp=ALU_ADD; end
                endcase
            end

            // -----------------------------------------------
            // MEM: Read or write data memory.
            //      Only LW, SW, SWAP reach this stage.
            // -----------------------------------------------
            MEM: begin
                case (Opcode)
                    LW:   begin MemRd=1'b1; MDRWrite=1'b1; end           // load: read memory -> MDR
                    SW:   begin MemWr=1'b1;                end           // store: Reg[rt] -> memory
                    SWAP: begin MemRd=1'b1; MemWr=1'b1; MDRWrite=1'b1; end // both read and write
                    default: begin end
                endcase
            end

            // -----------------------------------------------
            // WB: Write the result back to the register file.
            // -----------------------------------------------
            WB: begin
                RegWr = 1'b1;  // enable register write

                case (Opcode)
                    // R-type: Reg[rd] = ALUOut
                    ADD, SUB, AND_, OR_, XOR_, NOR_, SLL, SRL:
                        begin RegDst=2'b01; WBData=2'b00; end

                    // I-type ALU: Reg[rd] = ALUOut
                    ADDI, ANDI, ORI:
                        begin RegDst=2'b00; WBData=2'b00; end

                    // Load Word: Reg[rd] = MDR (data from memory)
                    LW:   begin RegDst=2'b00; WBData=2'b01; end

                    // Swap: Reg[rd] = old memory value (from MDR)
                    SWAP: begin RegDst=2'b00; WBData=2'b01; end

                    // Clear: Reg[rd] = 0
                    CLR:  begin RegDst=2'b01; WBData=2'b11; end

                    // JAL: R14 = return address (PC saved during ID)
                    JAL:  begin RegDst=2'b10; WBData=2'b10; end

                    default: RegWr = 1'b0;  // nothing to write
                endcase
            end

            default: begin end  // unknown state: do nothing

        endcase
    end

endmodule
