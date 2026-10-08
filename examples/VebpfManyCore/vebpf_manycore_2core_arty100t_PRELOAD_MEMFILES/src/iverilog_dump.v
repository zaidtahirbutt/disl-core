module iverilog_dump();
initial begin
    $dumpfile("top.fst");
    $dumpvars(0, top);
end
endmodule
