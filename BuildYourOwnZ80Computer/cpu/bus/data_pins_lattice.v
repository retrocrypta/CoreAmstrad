// Use this file with Lattice toolset instead of data_pins.v
//
// data_pins.v is auto-generated by Altera Quartus IDE from a
// block schematic file data_pins.bdf

module data_pins(
    bus_db_pin_oe,
    bus_db_pin_re,
    ctl_bus_db_we,
    clk,
    ctl_bus_db_oe,
    D,
    db
);

input wire bus_db_pin_oe;
input wire bus_db_pin_re;
input wire ctl_bus_db_we;
input wire clk;
input wire ctl_bus_db_oe;
inout wire [7:0] D;
inout wire [7:0] db;

reg [7:0] dout;

always@(negedge clk)
begin
    if (ctl_bus_db_we | bus_db_pin_re)
    begin
        if (bus_db_pin_re)
        dout <= D;
    else if (ctl_bus_db_we)
        dout <= db;
    end
end

assign db = ctl_bus_db_oe ? dout : 8'hZ;
assign D = bus_db_pin_oe ? dout : 8'hZ;

endmodule
