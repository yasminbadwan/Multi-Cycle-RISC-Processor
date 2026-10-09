// ====================================================
// Extender  -  Sign / Zero Extend immediate to 32 bits
// ====================================================
// ExtSel = 0  →  I-type: extend the 18-bit immediate  in[17:0]
// ExtSel = 1  →  J-type: extend the 26-bit offset     in[25:0]
// ExtOp  = 0  →  zero extend  (fill with 0s)
// ExtOp  = 1  →  sign extend  (fill with the sign bit)
// ====================================================

`timescale 1ns/1ps

module Extender(
    input  [25:0] in,      // 26-bit input (comes from instruction[25:0])
    input         extsel,  // 0 = I-type (18-bit), 1 = J-type (26-bit)
    input         extop,   // 0 = zero extend, 1 = sign extend
    output [31:0] Imm32    // 32-bit result
);

    assign Imm32 =
        (extsel) ?
            {{6{in[25]}}, in}           :   // J-type: sign-extend 26 bits
        (extop)  ?
            {{14{in[17]}}, in[17:0]}    :   // I-type: sign-extend 18 bits
            {14'b0, in[17:0]}           ;   // I-type: zero-extend 18 bits

endmodule
`timescale 1ns/1ps

module tb_Extender;

    reg  [25:0] in;
    reg         extsel;
    reg         extop;

    wire [31:0] Imm32;

    Extender uut (
        .in(in),
        .extsel(extsel),
        .extop(extop),
        .Imm32(Imm32)
    );

    task check;
        input [31:0] expected;
        begin
            #1;

            if(Imm32 !== expected)
                $display("ERROR: in=%b extsel=%b extop=%b Expected=%h Got=%h",
                          in, extsel, extop, expected, Imm32);
            else
                $display("PASS : in=%b extsel=%b extop=%b Result=%h",
                          in, extsel, extop, Imm32);
        end
    endtask

    initial begin

        $display("========== EXTENDER TEST START ==========");

        // =========================================
        // I-Type Zero Extension
        // =========================================
        extsel = 0;
        extop  = 0;
        in     = 26'd5;

        check(32'h00000005);

        // =========================================
        // I-Type Sign Extension (+ value)
        // =========================================
        extsel = 0;
        extop  = 1;
        in     = 26'd10;

        check(32'h0000000A);

        // =========================================
        // I-Type Sign Extension (-1)
        // 18-bit = 3FFFF
        // =========================================
        extsel = 0;
        extop  = 1;
        in     = 26'h0003FFFF;

        check(32'hFFFFFFFF);

        // =========================================
        // I-Type Sign Extension (most negative)
        // 18'b100000000000000000
        // =========================================
        extsel = 0;
        extop  = 1;
        in     = 26'h00020000;

        check(32'hFFFE0000);

        // =========================================
        // J-Type Sign Extension (+ value)
        // =========================================
        extsel = 1;
        extop  = 0;   // ignored in J-Type
        in     = 26'd20;

        check(32'h00000014);

        // =========================================
        // J-Type Sign Extension (-1)
        // 26'b11111111111111111111111111
        // =========================================
        extsel = 1;
        extop  = 1;
        in     = 26'h3FFFFFF;

        check(32'hFFFFFFFF);

        // =========================================
        // J-Type Sign Extension
        // sign bit = 1
        // =========================================
        extsel = 1;
        extop  = 1;
        in     = 26'h2000000;

        check(32'hFE000000);

        $display("========== EXTENDER TEST FINISHED ==========");
        $stop;

    end

endmodule