// =============================================================================
//  Desk Button for Simple Timer — parametric enclosure
//  A chamfered "slab" puck: round display on the left, a big arcade button with
//  a glowing light ring (halo) on the right, USB-C at the back.
//
//  Open in OpenSCAD (https://openscad.org), pick a part in the Customizer
//  (Window > Customizer) or set `part` below, then F6 (render) and F7 (export STL).
//
//  Printed parts (print orientation is applied automatically for single parts):
//    shell     main body, printed TOP FACE DOWN on the bed (no supports)
//    plate     bottom plate with board cradle, feet recesses and screw countersinks
//    halo      light ring around the button — print in WHITE / NATURAL PETG or PLA
//    spacer    washer between LED ring and button nut (leaves room for ring wires)
//    retainer  holds the round display against the top
//    strap     holds the ESP32-C3 SuperMini down by its USB-C connector
//
//  Units: millimetres. Origin = centre of footprint, z = 0 at the desk.
// =============================================================================

/* [What to show] */
part = "assembly"; // [assembly, exploded, shell, plate, halo, spacer, retainer, strap, print_all]
show_components = true;   // ghost button / display / board in assembly views

/* [Body] */
W       = 124;   // width  (X)
D       = 84;    // depth  (Y)
H       = 44;    // height (Z), includes bottom plate
R       = 16;    // corner radius (footprint)
ch      = 4;     // 45° chamfer on the top edge (prints cleanly face-down)
wall    = 2.4;   // side wall
top_t   = 3.0;   // top thickness
plate_t = 3.0;   // bottom plate thickness
clr     = 0.25;  // fit clearance between printed parts

/* [Button + light ring] */
btn_x       = 27;     // button centre
btn_y       = 2;
btn_hole    = 30.2;   // 30 mm arcade button (screw-nut type)
halo_od     = 56;     // visible glow ring diameter
halo_plug_d = 48;     // part of the halo that passes through the top
halo_lip    = 1.2;    // lip that sits flush in the top
halo_t      = 5.0;    // total halo thickness
ring_od     = 44.5;   // WS2812 16-LED ring outer diameter (measure yours!)
ring_id     = 31.75;  // WS2812 16-LED ring inner diameter
ring_pcb_t  = 1.6;
led_groove_w = 5.4;   // groove the LEDs sit in
led_groove_d = 1.8;
spacer_od   = 44;
spacer_t    = 2.5;

/* [Display: 1.28" round GC9A01 module] */
disp_x      = -32;
disp_y      = 2;
disp_view_d = 33.0;   // visible window (active area is 32.4)
disp_glass_d = 35.8;  // glass outer diameter (measure yours!)
disp_pcb_d  = 39.0;   // round PCB diameter (measure yours!)
disp_pcb_t  = 1.6;
disp_skin   = 1.0;    // plastic left in front of the glass
disp_back_clear = 4;  // room behind the display PCB for parts and wires
deco_groove = true;   // thin ring engraved around the display

/* [Board: ESP32-C3 SuperMini] */
board_x  = -10;
board_w  = 18.0;
board_l  = 22.6;
board_t  = 1.2;
usb_overhang = 0.8;   // how far the USB-C sticks out past the PCB edge
usb_center_above_pcb = 1.6;
usb_h    = 3.2;       // USB-C receptacle height
pad_h    = 1.5;       // board sits on two strips this tall

/* [Screws + feet] */
boss_r   = 3.5;
pilot_d  = 2.6;       // M3 self-tapping pilot (use 4.0 for M3 heat-set inserts)
m3_clear = 3.4;
m3_head  = 6.4;
m2_pilot = 1.7;
m2_clear = 2.4;
foot_d   = 10;        // stick-on rubber feet
foot_depth = 1.0;

$fn = 96;

// ---------------------------------------------------------------- derived
Wi = W - 2*wall;
Di = D - 2*wall;
Ri = R - wall;
c2 = max(0, ch - top_t + wall*(sqrt(2) - 1));   // inner chamfer keeps the wall even
bd = (R - wall - boss_r + 0.8) / sqrt(2);
boss_pts = [for (sx = [-1, 1], sy = [-1, 1]) [sx*(W/2 - R + bd), sy*(D/2 - R + bd)]];

r_led       = (ring_od + ring_id) / 4;
pcb_back_z  = H - top_t - disp_pcb_t;            // back of the display PCB
disp_post_pts = [[disp_x - (disp_pcb_d/2 + 3.2), disp_y], [disp_x + (disp_pcb_d/2 + 3.2), disp_y]];

board_top_z = plate_t + pad_h + board_t;
board_cy    = D/2 - wall - 0.3 - usb_overhang - board_l/2;
usb_z       = board_top_z + usb_center_above_pcb;
usb_y       = board_cy + board_l/2 - 3.5;        // where the strap presses the receptacle
strap_z     = board_top_z + usb_h;               // strap underside
strap_pts   = [[board_x - (board_w/2 + 4.4), usb_y], [board_x + (board_w/2 + 4.4), usb_y]];

// ---------------------------------------------------------------- helpers
module rrect(w, d, r, h) {
    linear_extrude(h) offset(r = r) square([w - 2*r, d - 2*r], center = true);
}
module annulus(ro, ri, h) {
    difference() { cylinder(r = ro, h = h); translate([0, 0, -1]) cylinder(r = ri, h = h + 2); }
}
module sector(r, a0, a1, h) {   // pie slice from angle a0 to a1
    linear_extrude(h) polygon(concat([[0, 0]], [for (a = [a0 : (a1 - a0)/24 : a1]) [r*cos(a), r*sin(a)]]));
}
module slot_y(w, h, r, len) {   // rounded rectangle in XZ, extruded along +Y
    rotate([-90, 0, 0]) linear_extrude(len) offset(r = r) square([w - 2*r, h - 2*r], center = true);
}
module outer() {
    hull() {
        rrect(W, D, R, H - ch);
        translate([0, 0, H - 0.01]) rrect(W - 2*ch, D - 2*ch, R - ch, 0.01);
    }
}
module inner() {
    hull() {
        translate([0, 0, -1]) rrect(Wi, Di, Ri, H - top_t - c2 + 1);
        translate([0, 0, H - top_t - 0.01]) rrect(Wi - 2*c2, Di - 2*c2, Ri - c2, 0.01);
    }
}

// ---------------------------------------------------------------- shell
module shell() {
    difference() {
        intersection() {
            outer();
            union() {
                difference() { outer(); inner(); }
                // corner screw bosses (plate screws go into these)
                for (p = boss_pts) translate([p[0], p[1], plate_t]) cylinder(r = boss_r, h = H);
                // display retainer posts
                for (p = disp_post_pts)
                    translate([p[0], p[1], pcb_back_z - disp_back_clear])
                        cylinder(r = 3, h = disp_back_clear + disp_pcb_t + 0.01);
            }
        }
        // halo: flush recess + through hole
        translate([btn_x, btn_y, H - halo_lip]) cylinder(d = halo_od + 2*clr, h = 5);
        translate([btn_x, btn_y, H - top_t - 1]) cylinder(d = halo_plug_d + 2*clr, h = top_t + 5);
        // display: window, bevel, glass pocket, optional decorative groove
        translate([disp_x, disp_y, H - top_t - 1]) cylinder(d = disp_view_d, h = top_t + 5);
        translate([disp_x, disp_y, H - 1]) cylinder(d1 = disp_view_d, d2 = disp_view_d + 2.4, h = 1.21);
        translate([disp_x, disp_y, H - top_t - 0.01]) cylinder(d = disp_glass_d + 2*clr, h = top_t - disp_skin + 0.01);
        if (deco_groove)
            translate([disp_x, disp_y, H - 0.6]) annulus(disp_view_d/2 + 5.2, disp_view_d/2 + 4.0, 1);
        // USB-C opening + outside relief so the plug seats fully
        translate([board_x, D/2 - wall - 1, usb_z]) slot_y(10, 4.4, 1.6, wall + 3);
        translate([board_x, D/2 - (wall - 1.0), usb_z]) slot_y(13, 8, 3, 5);
        // screw pilots
        for (p = boss_pts) translate([p[0], p[1], plate_t - 0.01]) cylinder(d = pilot_d, h = 12);
        for (p = disp_post_pts)
            translate([p[0], p[1], pcb_back_z - disp_back_clear - 0.01])
                cylinder(d = m2_pilot, h = disp_back_clear + disp_pcb_t + top_t - disp_skin);
    }
}

// ---------------------------------------------------------------- bottom plate
module plate() {
    difference() {
        union() {
            rrect(Wi - 2*clr, Di - 2*clr, Ri - clr, plate_t);
            translate([board_x, board_cy, plate_t - 0.01]) cradle();
            for (p = strap_pts) translate([p[0], p[1], plate_t - 0.01]) cylinder(r = 2.8, h = strap_z - plate_t + 0.01);
        }
        // countersunk M3 screw holes
        for (p = boss_pts) translate([p[0], p[1], 0]) {
            translate([0, 0, -1]) cylinder(d = m3_clear, h = plate_t + 2);
            translate([0, 0, -0.01]) cylinder(d1 = m3_head, d2 = m3_clear, h = (m3_head - m3_clear)/2);
        }
        // rubber foot recesses
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx*(Wi/2 - 14), sy*(Di/2 - 12), -0.01]) cylinder(d = foot_d + 0.6, h = foot_depth + 0.01);
        // strap screw pilots
        for (p = strap_pts) translate([p[0], p[1], plate_t]) cylinder(d = m2_pilot, h = 20);
    }
}
module cradle() {   // frame around the board, open at the USB end
    fw = board_w + 0.6; fl = board_l + 0.6; t = 1.6; h = pad_h + board_t;
    difference() {
        translate([-fw/2 - t, -fl/2 - t, 0]) cube([fw + 2*t, fl + t, h]);
        translate([-fw/2, -fl/2, -1]) cube([fw, fl + 5, h + 2]);
    }
    // two strips under the middle of the board (keeps solder joints on the pin rows clear)
    for (sx = [-1, 1]) translate([sx*3 - 1, -fl/2, 0]) cube([2, fl, pad_h]);
}

// ---------------------------------------------------------------- halo (light ring)
module halo() {
    translate([btn_x, btn_y, 0]) difference() {
        union() {
            translate([0, 0, H - halo_lip]) cylinder(d = halo_od, h = halo_lip);
            translate([0, 0, H - halo_t]) cylinder(d = halo_plug_d, h = halo_t - halo_lip + 0.01);
        }
        translate([0, 0, H - halo_t - 1]) cylinder(d = btn_hole, h = halo_t + 2);
        // pocket for the LED ring PCB
        translate([0, 0, H - halo_t - 0.01]) cylinder(d = ring_od + 0.5, h = ring_pcb_t + 0.01);
        // groove the LEDs sit in
        translate([0, 0, H - halo_t + ring_pcb_t - 0.01])
            annulus(r_led + led_groove_w/2, r_led - led_groove_w/2, led_groove_d + 0.01);
    }
}

// ---------------------------------------------------------------- spacer (under LED ring)
module spacer() {
    translate([btn_x, btn_y, H - halo_t - spacer_t]) difference() {
        annulus(spacer_od/2, btn_hole/2, spacer_t);
        // notch for the ring's solder pads / wires (faces the back, +Y)
        difference() {
            translate([0, 0, -1]) sector(spacer_od, 55, 125, spacer_t + 2);
            translate([0, 0, -2]) cylinder(d = btn_hole + 3.6, h = spacer_t + 4);
        }
    }
}

// ---------------------------------------------------------------- display retainer
module retainer() {
    z0 = pcb_back_z - disp_back_clear - 2;
    pr = disp_pcb_d/2;
    translate([0, 0, z0]) difference() {
        union() {
            // base ring + arms to the two posts
            translate([disp_x, disp_y, 0]) annulus(pr + 1, pr - 2.5, 2);
            for (p = disp_post_pts) hull() {
                translate([p[0], p[1], 0]) cylinder(r = 3.5, h = 2);
                translate([disp_x + sign(p[0] - disp_x)*(pr - 1), disp_y, 0]) cylinder(r = 3.5, h = 2);
            }
            // tube that presses the PCB edge, with a gap for the wires (+Y)
            translate([disp_x, disp_y, 0]) difference() {
                annulus(pr, pr - 2.5, disp_back_clear + 2);
                translate([0, 0, 2]) sector(pr + 5, 62, 118, disp_back_clear + 1);
            }
        }
        for (p = disp_post_pts) translate([p[0], p[1], -1]) cylinder(d = m2_clear, h = 10);
    }
}

// ---------------------------------------------------------------- board strap
module strap() {
    p0 = strap_pts[0]; p1 = strap_pts[1];
    difference() {
        hull() {
            translate([p0[0], p0[1], strap_z]) cylinder(r = 3.2, h = 2.5);
            translate([p1[0], p1[1], strap_z]) cylinder(r = 3.2, h = 2.5);
        }
        for (p = strap_pts) translate([p[0], p[1], strap_z - 1]) cylinder(d = m2_clear, h = 5);
    }
}

// ---------------------------------------------------------------- ghost components
module components() {
    // arcade button (bezel + body + microswitch)
    color("crimson") translate([btn_x, btn_y, H]) cylinder(d = 33, h = 6);
    color("crimson", 0.8) translate([btn_x, btn_y, H + 6]) cylinder(d1 = 26, d2 = 24, h = 4);
    %translate([btn_x, btn_y, H - 33]) cylinder(d = 28.5, h = 33);
    // LED ring
    color("green") translate([btn_x, btn_y, H - halo_t]) annulus(ring_od/2, ring_id/2, ring_pcb_t);
    // round display
    color("black") translate([disp_x, disp_y, H - top_t + 0.2]) cylinder(d = disp_glass_d, h = top_t - disp_skin - 0.2);
    color("navy") translate([disp_x, disp_y, pcb_back_z]) cylinder(d = disp_pcb_d, h = disp_pcb_t);
    // ESP32-C3 SuperMini
    color("darkslateblue") translate([board_x - board_w/2, board_cy - board_l/2, board_top_z - board_t])
        cube([board_w, board_l, board_t]);
    color("silver") translate([board_x - 4.5, board_cy + board_l/2 - 7.3 + usb_overhang, board_top_z])
        cube([9, 7.3, usb_h]);
}

// ---------------------------------------------------------------- views
module assembly(explode = 0) {
    color("#2b2d31") translate([0, 0, 3*explode]) shell();
    color("#2b2d31") plate();
    color("white", 0.85) translate([0, 0, 5*explode]) halo();
    color("dimgray") translate([0, 0, 2*explode]) spacer();
    color("dimgray") translate([0, 0, 1.5*explode]) retainer();
    color("dimgray") translate([0, 0, 0.6*explode]) strap();
    if (show_components && explode == 0) components();
}

// print orientation: flip parts whose good face is the top, put everything on z = 0
module flip_at(ztop) { translate([0, 0, ztop]) rotate([180, 0, 0]) children(); }

module print_part(p) {
    if (p == "shell")    flip_at(H) shell();
    if (p == "plate")    plate();
    if (p == "halo")     flip_at(H) translate([-btn_x, -btn_y, 0]) halo();
    if (p == "spacer")   translate([-btn_x, -btn_y, -(H - halo_t - spacer_t)]) spacer();
    if (p == "retainer") translate([-disp_x, -disp_y, -(pcb_back_z - disp_back_clear - 2)]) retainer();
    if (p == "strap")    flip_at(strap_z + 2.5) translate([-board_x, -usb_y, 0]) strap();
}

if (part == "assembly")  assembly(0);
else if (part == "exploded") assembly(12);
else if (part == "print_all") {
    print_part("shell");
    translate([0, D + 10, 0]) print_part("plate");
    translate([W/2 + 40, 0, 0]) print_part("halo");
    translate([W/2 + 40, -64, 0]) print_part("spacer");
    translate([-W/2 - 36, 0, 0]) print_part("retainer");
    translate([-W/2 - 36, -40, 0]) print_part("strap");
}
else print_part(part);
