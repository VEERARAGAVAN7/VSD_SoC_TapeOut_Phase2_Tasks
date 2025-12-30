// SPDX-FileCopyrightText: 2025 Efabless Corporation/VSD
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

/*
StriVe housekeeping SPI testbench - PHASE-2 UPDATED WITH EXTERNAL RESET (reset_v)
Simulates external supervisor IC behavior for reset signal handling
*/

`timescale 1 ns / 1 ps

`include "__uprj_netlists.v"
`include "caravel_netlists.v"
`include "spiflash.v"
`include "tbuart.v"

module hkspi_tb;
    reg clock;
    reg SDI, CSB, SCK, RSTB;
    reg reset_v;                    // ✅ PHASE-2: External reset from supervisor IC
    reg power1, power2;

    wire gpio;
    wire [15:0] checkbits;
    wire [37:0] mprj_io;
    wire uart_tx;
    wire uart_rx;

    wire flash_csb;
    wire flash_clk;
    wire flash_io0;
    wire flash_io1;
    wire flash_io2;
    wire flash_io3;

    wire SDO;
    integer i;

    // Clock generation: 40MHz (25ns period = 12.5ns half-period)
    always #12.5 clock <= (clock === 1'b0);

    initial begin
        clock = 0;
    end

    // Power-up sequence (simulates board power)
    initial begin
        power1 <= 1'b0;
        power2 <= 1'b0;
        #200;                       // Wait 200ns
        power1 <= 1'b1;             // 3.3V supply comes up
        #200;                       // Wait 200ns
        power2 <= 1'b1;             // 1.8V supply comes up
    end

    // ====================================================================
    // SPI TASK DEFINITIONS - Housekeeping SPI Communication
    // ====================================================================

    task start_csb;
        begin
            SCK <= 1'b0;
            SDI <= 1'b0;
            CSB <= 1'b0;            // Chip Select LOW
            #50;
        end
    endtask

    task end_csb;
        begin
            SCK <= 1'b0;
            SDI <= 1'b0;
            CSB <= 1'b1;            // Chip Select HIGH
            #50;
        end
    endtask

    task write_byte;
        input [7:0] odata;
        begin
            SCK <= 1'b0;
            for (i=7; i >= 0; i--) begin
                #50;
                SDI <= odata[i];    // Set data bit
                #50;
                SCK <= 1'b1;        // Clock pulse
                #100;
                SCK <= 1'b0;
            end
        end
    endtask

    task read_byte;
        output [7:0] idata;
        begin
            SCK <= 1'b0;
            SDI <= 1'b0;
            for (i=7; i >= 0; i--) begin
                #50;
                idata[i] = SDO;     // Sample data bit
                #50;
                SCK <= 1'b1;        // Clock pulse
                #100;
                SCK <= 1'b0;
            end
        end
    endtask

    task read_write_byte
        (input [7:0] odata,
        output [7:0] idata);
        begin
            SCK <= 1'b0;
            for (i=7; i >= 0; i--) begin
                #50;
                SDI <= odata[i];    // Set output bit
                idata[i] = SDO;     // Sample input bit
                #50;
                SCK <= 1'b1;        // Clock pulse
                #100;
                SCK <= 1'b0;
            end
        end
    endtask

    // ====================================================================
    // MAIN TEST ROUTINE - Housekeeping SPI and System Initialization
    // ====================================================================

    reg [7:0] tbdata;

    initial begin
        $dumpfile("hkspi.vcd");
        $dumpvars(0, hkspi_tb);

        // Initialize SPI control signals
        CSB <= 1'b1;                // Chip Select HIGH (inactive)
        SCK <= 1'b0;                // Clock LOW
        SDI <= 1'b0;                // Data LOW
        RSTB <= 1'b0;               // Synchronous reset LOW
	
        // ================================================================
        // PHASE-2 MODIFICATION: Initialize External Reset Signal
        // ================================================================
        
	            // ✅ PHASE-2: External reset ACTIVE (LOW)
                                    // This simulates supervisor IC holding reset during power-up

        // Delay for power supplies to stabilize
        #1000;
        
        // Release external reset after 1000ns
        // This simulates supervisor IC behavior (like MAX809):
        // - Supervisor detects supply has ramped up
        // - Supervisor releases reset_v pin (allows it to go HIGH)
        RSTB <= 1'b1;
                    // ✅ PHASE-2: External reset RELEASED (HIGH)
                                   // System now begins initialization sequence
        #2000;

        // At this point:
        // - All GPIO pads are ENABLED (from chip_io.porb_h = reset_v = HIGH)
        // - Housekeeping registers INITIALIZED (from housekeeping.porb = rstbl)
        // - Clock dividers FUNCTIONAL (from caravel_clocking.porb = rstbl)
        // - System ready for operation

        // ================================================================
        // TEST 1: Read Housekeeping SPI Register 3 (Product ID)
        // ================================================================
        start_csb();
        write_byte(8'h40);          // Read stream command
        write_byte(8'h03);          // Address (register 3 = product ID)
        read_byte(tbdata);
        end_csb();
        #10;
        $display("Read data = 0x%02x (should be 0x11)", tbdata);

        // ================================================================
        // TEST 2: Toggle External Reset via SPI
        // ================================================================
        start_csb();
        write_byte(8'h80);          // Write stream command
        write_byte(8'h0b);          // Address (register 7 = external reset)
        write_byte(8'h01);          // Data = 0x01 (apply external reset)
        end_csb();

        start_csb();
        write_byte(8'h80);          // Write stream command
        write_byte(8'h0b);          // Address (register 7 = external reset)
        write_byte(8'h00);          // Data = 0x00 (release external reset)
        end_csb();

        // ================================================================
        // TEST 3: Read All Housekeeping Registers (0-18)
        // ================================================================
        start_csb();
        write_byte(8'h40);          // Read stream command
        write_byte(8'h00);          // Address (register 0)
        read_byte(tbdata);

        $display("Read register 0 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 1 = 0x%02x (should be 0x04)", tbdata);
        if(tbdata !== 8'h04) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 2 = 0x%02x (should be 0x56)", tbdata);
        if(tbdata !== 8'h56) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed, %02x", tbdata);
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed, %02x", tbdata);
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 3 = 0x%02x (should be 0x11)", tbdata);
        if(tbdata !== 8'h11) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed, %02x", tbdata);
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed, %02x", tbdata);
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 4 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 5 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 6 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 7 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 8 = 0x%02x (should be 0x02)", tbdata);
        if(tbdata !== 8'h02) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 9 = 0x%02x (should be 0x01)", tbdata);
        if(tbdata !== 8'h01) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 10 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 11 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 12 = 0x%02x (should be 0x00)", tbdata);
        if(tbdata !== 8'h00) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 13 = 0x%02x (should be 0xff)", tbdata);
        if(tbdata !== 8'hff) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 14 = 0x%02x (should be 0xef)", tbdata);
        if(tbdata !== 8'hef) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 15 = 0x%02x (should be 0xff)", tbdata);
        if(tbdata !== 8'hff) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 16 = 0x%02x (should be 0x03)", tbdata);
        if(tbdata !== 8'h03) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 17 = 0x%02x (should be 0x12)", tbdata);
        if(tbdata !== 8'h12) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        read_byte(tbdata);
        $display("Read register 18 = 0x%02x (should be 0x04)", tbdata);
        if(tbdata !== 8'h04) begin
            `ifdef GL
                $display("Monitor: Test HK SPI (GL) Failed");
                $finish;
            `else
                $display("Monitor: Test HK SPI (RTL) Failed");
                $finish;
            `endif
        end

        end_csb();

        // ================================================================
        // TEST PASS/FAIL REPORT
        // ================================================================
        `ifdef GL
            $display("Monitor: Test HK SPI (GL) Passed");
        `else
            $display("Monitor: Test HK SPI (RTL) Passed");
        `endif

        #1000;
        $finish;
    end

    // ====================================================================
    // POWER SUPPLY AND SIGNAL ASSIGNMENTS
    // ====================================================================

    wire VDD3V3;
    wire VDD1V8;
    wire VSS;

    assign VDD3V3 = power1;         // 3.3V supply
    assign VDD1V8 = power2;         // 1.8V supply
    assign VSS = 1'b0;              // Ground

    wire hk_sck;
    wire hk_csb;
    wire hk_sdi;

    assign hk_sck = SCK;
    assign hk_csb = CSB;
    assign hk_sdi = SDI;

    assign checkbits = mprj_io[31:16];
    assign uart_tx = mprj_io[6];
    assign mprj_io[5] = uart_rx;
    assign mprj_io[4] = hk_sck;
    assign mprj_io[3] = hk_csb;
    assign mprj_io[2] = hk_sdi;
    assign SDO = mprj_io[1];

    // ====================================================================
    // INSTANTIATE DUT - vsdcaravel (Top Module)
    // ====================================================================

    vsdcaravel uut (
        .vddio      (VDD3V3),
        .vddio_2    (VDD3V3),
        .vssio      (VSS),
        .vssio_2    (VSS),
        .vdda       (VDD3V3),
        .vssa       (VSS),
        .vccd       (VDD1V8),
        .vssd       (VSS),
        .vdda1      (VDD3V3),
        .vdda1_2    (VDD3V3),
        .vdda2      (VDD3V3),
        .vssa1      (VSS),
        .vssa1_2    (VSS),
        .vssa2      (VSS),
        .vccd1      (VDD1V8),
        .vccd2      (VDD1V8),
        .vssd1      (VSS),
        .vssd2      (VSS),
        .clock      (clock),
        .gpio       (gpio),
        .mprj_io    (mprj_io),
        .flash_csb  (flash_csb),
        .flash_clk  (flash_clk),
        .flash_io0  (flash_io0),
        .flash_io1  (flash_io1),
        .reset_v    (RSTB)       // ✅ PHASE-2: Connect external reset signal
    );

    // ====================================================================
    // INSTANTIATE SPI FLASH
    // ====================================================================

    spiflash #(
        .FILENAME("hkspi.hex")
    ) spiflash (
        .csb(flash_csb),
        .clk(flash_clk),
        .io0(flash_io0),
        .io1(flash_io1),
        .io2(),                     // not used
        .io3()                      // not used
    );

    // ====================================================================
    // INSTANTIATE UART MONITOR
    // ====================================================================

    tbuart tbuart (
        .ser_rx(uart_tx)
    );

endmodule

`default_nettype wire
