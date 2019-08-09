(*always_ready,always_enabled*)
interface Gte4;
   method Bit#(1) o;
   method Bit#(1) odiv2;
   method Action i ((*port="i"*) Bit#(1) x);
   method Action ib ((*port="ib"*) Bit#(1) x);
endinterface

import "BVI" IBUFDS_GTE4 =
module vibufds_gte4(Gte4);
   method O o;
   method ODIV2 odiv2;
   method i(I) enable((*inhigh*)en0);
   method ib(IB) enable((*inhigh*)en1);
endmodule

(*synthesize*)
module ibufds_gte4(Gte4);
   let _ifc <- vibufds_gte4;
   return _ifc;
endmodule
