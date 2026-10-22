package cv_pkt_pkg;

typedef struct packed {
	logic [7: 0] r;
	logic [7: 0] g;
	logic [7: 0] b;
} pkt_rgb;

typedef struct packed {
	logic [7: 0] b;
	logic [7: 0] g;
	logic [7: 0] r;
} pkt_bgr;


typedef struct packed {
	logic [7: 0] h;
	logic [7: 0] s;
	logic [7: 0] v;
} pkt_hsv;

endpackage: cv_pkt_pkg
