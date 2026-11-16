// =============================================================================
//  Desk Button for Simple Timer — parametric enclosure (v2: "press bar")
//  A clean block: a wide OLED screen across the front, and a long flat press bar
//  across the top (hinged at the back, like a clock-radio snooze bar) with a
//  clicky low-profile keyboard switch underneath.
//
//  Open in OpenSCAD (https://openscad.org), pick a part in the Customizer
//  (Window > Customizer) or set `part` below, then F6 (render) and F7 (export STL),
//  or just run export-stl.ps1.
//
//  Printed parts (single parts are exported already in print orientation):
//    shell   main body, printed FRONT FACE DOWN, open at the back (no supports)
//    bezel   black screen panel that clips into the front           — print BLACK
//    bar     the press bar                                           — print BLACK
//    back    back cover with the board shelf and USB-C opening
//    clamp   holds the OLED against the front                        — print 2
//
//  Units: millimetres. Origin = centre of footprint, front is -Y, z = 0 at the desk.
// =============================================================================

/* [What to show] */
part = "assembly"; // [assembly, exploded, shell, bezel, bar, back, clamp, print_all]
show_components = true;   // ghost OLED / switch / board in assembly views

/* [Body] */
W       = 132;   // width
D       = 72;    // depth
H       = 56;    // height (front face)
edge_r  = 3;     // rounded outer edges
wall    = 2.4;   // sides, top, bottom
front_t = 3.2;   // front wall
back_t  = 3.0;   // back cover
clr     = 0.25;  // fit clearance between printed parts

/* [Screen panel + OLED: 3.12" 256x64 SSD1322] */
panel_w   = 121;     // black front panel (the "screen" look)
panel_h   = 45;
panel_r   = 5;
panel_t   = 1.6;
oled_z    = 28;      // centre height of the screen
glass_w   = 88.0;    // measure yours!
glass_h   = 27.8;
glass_t   = 2.0;
active_w  = 76.8;
active_h  = 19.2;
active_dx = 0;       // active area offset from glass centre (check your datasheet)
active_dz = 0;
oled_pcb_w = 100.5;  // measure yours!
oled_pcb_h = 33.5;
oled_pcb_t = 1.6;
clamp_x   = 30;      // the two clamps press the PCB's top/bottom edges at x = ±clamp_x

/* [Press bar + switch (Kailh Choc v1)] */
bar_w      = 104;
bar_t      = 4;
bar_proud  = 3;      // how far the bar sits above the top at rest
slot_front = 9;      // top margin in front of the bar
slot_d     = 46;     // slot depth (front to back)
front_gap  = 1.0;    // bigger gap at the front: the bar swings forward a little as it goes down
hinge_drop = 4;      // hinge axis below the top's underside
ear_r      = 3;
switch_y   = -8;     // switch position (centre of bar width)
choc_hole  = 13.8;
choc_plate_t = 1.3;
choc_above_plate = 5.0;  // plate top to stem top, at rest (measure yours!)
shelf_top  = 49;     // switch plate top (z)

/* [Board: ESP32-C3 SuperMini on the back cover] */
board_x  = -30;
board_w  = 18.0;
board_l  = 22.6;
board_t  = 1.2;
usb_overhang = 0.8;
usb_h    = 3.2;
pad_h    = 1.5;
board_shelf_z = 8;   // top of the shelf the board lies on

/* [Screws + feet] */
boss_r   = 3.5;
pilot_d  = 2.6;      // M3 self-tapping pilot (4.0 for M3 heat-set inserts)
m3_clear = 3.4;
m3_head  = 6.4;
m2_pilot = 1.7;
m2_clear = 2.4;
foot_d   = 10;
foot_depth = 1.0;

$fn = 64;

// ---------------------------------------------------------------- derived
y_front  = -D/2;
y_fi     = y_front + front_t;          // front wall inner face
y_back   = D/2;
y_bi     = y_back - back_t;            // where the back cover's inner face sits
z_top_in = H - wall;                   // top's underside
iw = W/2 - wall;                       // inner half-width

slot_y0 = y_front + slot_front;
slot_y1 = slot_y0 + slot_d;
slot_w  = bar_w + 2*0.4;
bar_y0  = slot_y0 + front_gap;
bar_y1  = slot_y1 - 0.4;
bar_z0  = H + bar_proud - bar_t;       // bar underside at rest
hinge_y = slot_y1 - 5;
hinge_z = z_top_in - hinge_drop;
ear_x   = bar_w/2 - 2 - 4;             // inner face of each ear (ears are 4 thick)
post_x0 = bar_w/2 - 0.6;               // hinge posts start just outside the ears
pad_len = bar_z0 - (shelf_top + choc_above_plate) + 0.3;   // 0.3 mm preload

glass_y0 = y_front + panel_t;          // glass front face (pressed by the bezel)
pcb_y0   = glass_y0 + glass_t;         // OLED PCB front
pcb_y1   = pcb_y0 + oled_pcb_t;        // OLED PCB back
clamp_post_z = [oled_z - oled_pcb_h/2 - 3.5, oled_z + oled_pcb_h/2 + 3.5];

boss_pts = [for (sx = [-1, 1], sz = [wall + boss_r - 0.8, z_top_in - boss_r + 0.8]) [sx*(iw - boss_r + 0.8), sz]];

board_y1 = y_bi - 0.3 - usb_overhang;  // PCB back edge
board_y0 = board_y1 - board_l;
board_z0 = board_shelf_z + pad_h;
usb_z    = board_z0 + board_t + 1.6;

// ---------------------------------------------------------------- helpers
module rbox(x0, x1, y0, y1, z0, z1, r) {
    hull() for (x = [x0 + r, x1 - r], y = [y0 + r, y1 - r], z = [z0 + r, z1 - r])
        translate([x, y, z]) sphere(r, $fn = 24);
}
module rrect_xz(w, h, r, t) {          // rounded rectangle in the XZ plane, extruded along +Y
    rotate([-90, 0, 0]) linear_extrude(t) offset(r = r) square([w - 2*r, h - 2*r], center = true);
}
module rrect_xy(w, d, r, t) {
    linear_extrude(t) offset(r = r) square([w - 2*r, d - 2*r], center = true);
}
module box(x0, x1, y0, y1, z0, z1) { translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]); }

// ---------------------------------------------------------------- shell
module shell() {
    difference() {
        union() {
            difference() {
                rbox(-W/2, W/2, y_front, y_back, 0, H, edge_r);
                box(-iw, iw, y_fi, y_back + 1, wall, z_top_in);            // cavity, open at the back
            }
            // back-cover screw bosses (run front to back in the corners)
            for (p = boss_pts) translate([p[0], y_fi - 0.01, p[1]]) rotate([-90, 0, 0])
                cylinder(r = boss_r, h = y_bi - y_fi + 0.01);
            // OLED clamp posts
            for (sx = [-1, 1], z = clamp_post_z) translate([sx*clamp_x, y_fi - 0.01, z]) rotate([-90, 0, 0])
                cylinder(r = 3, h = pcb_y1 + 3 - y_fi + 0.01);
            // switch plate, joined to the front wall and the top (prints as a fin, no supports)
            switch_plate();
            // hinge posts (45° front face so they print without supports)
            for (sx = [-1, 1]) hull() {
                box(sx > 0 ? post_x0 : -iw - 0.5, sx > 0 ? iw + 0.5 : -post_x0,
                    hinge_y - ear_r - 1 - (z_top_in - hinge_z + ear_r + 1), hinge_y + ear_r + 1, z_top_in - 0.5, z_top_in + 0.01);
                box(sx > 0 ? post_x0 : -iw - 0.5, sx > 0 ? iw + 0.5 : -post_x0,
                    hinge_y - ear_r - 1, hinge_y + ear_r + 1, hinge_z - ear_r - 1, z_top_in);
            }
        }
        // screen panel recess, glass opening
        translate([0, y_front - 1, oled_z]) rrect_xz(panel_w + 2*clr, panel_h + 2*clr, panel_r, panel_t + 1);
        translate([0, y_front - 1, oled_z]) rrect_xz(glass_w + 2*clr, glass_h + 2*clr, 0.5, front_t + 2);
        // bar slot; a 2 mm ledge is left standing at the back for the bar's back edge to rest on
        difference() {
            box(-slot_w/2, slot_w/2, slot_y0, slot_y1, z_top_in - 1, H + 1);
            box(-38, 38, slot_y1 - 2, slot_y1 + 1, z_top_in - 2, bar_z0);
        }
        // screw pilots
        for (p = boss_pts) translate([p[0], y_bi - 12, p[1]]) rotate([-90, 0, 0]) cylinder(d = pilot_d, h = 13);
        for (sx = [-1, 1], z = clamp_post_z) translate([sx*clamp_x, y_fi, z]) rotate([-90, 0, 0]) cylinder(d = m2_pilot, h = 20);
        for (sx = [-1, 1]) translate([sx > 0 ? post_x0 - 1 : -post_x0 - 7, hinge_y, hinge_z])
            rotate([0, 90, 0]) cylinder(d = pilot_d, h = 8);
        // rubber feet
        for (sx = [-1, 1], sy = [-1, 1]) translate([sx*(W/2 - 16), sy*(D/2 - 12), -0.01]) cylinder(d = foot_d + 0.6, h = foot_depth + 0.01);
    }
}

module switch_plate() {
    pw = 22; y_end = switch_y + 10;
    difference() {
        union() {
            box(-pw/2, pw/2, y_fi - 0.01, y_end, shelf_top - 3, shelf_top);
            box(-pw/2, pw/2, y_fi - 0.01, slot_y0, shelf_top - 3, z_top_in + 0.01);   // tie into the top
        }
        translate([-choc_hole/2, switch_y - choc_hole/2, shelf_top - 5]) cube([choc_hole, choc_hole, 10]);
        // thin it to plate thickness around the switch so the clips can grab
        translate([-15.5/2, switch_y - 15.5/2, shelf_top - 3.5]) cube([15.5, 15.5, 3.5 - choc_plate_t]);
    }
}

// ---------------------------------------------------------------- bezel (black screen panel)
module bezel() {
    difference() {
        translate([0, y_front, oled_z]) rrect_xz(panel_w, panel_h, panel_r, panel_t);
        translate([active_dx, y_front - 1, oled_z + active_dz]) rrect_xz(active_w + 1.2, active_h + 1.2, 1, panel_t + 2);
    }
}

// ---------------------------------------------------------------- press bar
module bar() {
    difference() {
        union() {
            hull() {
                translate([0, (bar_y0 + bar_y1)/2, bar_z0]) rrect_xy(bar_w, bar_y1 - bar_y0, 2.5, bar_t - 1);
                translate([0, (bar_y0 + bar_y1)/2, bar_z0]) rrect_xy(bar_w - 2, bar_y1 - bar_y0 - 2, 1.5, bar_t);
            }
            // hinge ears
            for (sx = [-1, 1]) hull() {
                box(sx > 0 ? ear_x : -ear_x - 4, sx > 0 ? ear_x + 4 : -ear_x,
                    hinge_y - ear_r, min(hinge_y + ear_r, bar_y1 - 0.5), bar_z0 - 0.5, bar_z0 + 0.01);
                translate([sx > 0 ? ear_x : -ear_x - 4, hinge_y, hinge_z]) rotate([0, 90, 0]) cylinder(r = ear_r, h = 4);
            }
            // pusher pad over the switch stem
            translate([-4, switch_y - 4, bar_z0 - pad_len]) cube([8, 8, pad_len + 0.01]);
        }
        for (sx = [-1, 1]) translate([sx > 0 ? ear_x - 1 : -ear_x - 5, hinge_y, hinge_z]) rotate([0, 90, 0]) cylinder(d = m3_clear, h = 6);
    }
}

// ---------------------------------------------------------------- back cover
module back() {
    difference() {
        union() {
            box(-iw + clr, iw - clr, y_bi, y_back, wall + clr, z_top_in - clr);
            // board shelf, side rails, a low lip at the front edge, and a fin over the USB-C
            fw = board_w + 0.6;
            box(board_x - fw/2 - 1.6, board_x + fw/2 + 1.6, board_y0 - 2.5, y_bi + 0.01, board_shelf_z - 2, board_shelf_z);
            for (sx = [-1, 1]) box(board_x + sx*(fw/2 + 0.8) - 0.8, board_x + sx*(fw/2 + 0.8) + 0.8,
                                   board_y0 - 2.5, y_bi + 0.01, board_shelf_z - 0.01, board_z0 + board_t);
            for (sx = [-1, 1]) box(board_x + sx*3 - 1, board_x + sx*3 + 1, board_y0, y_bi + 0.01, board_shelf_z - 0.01, board_z0);
            box(board_x - fw/2 - 1.6, board_x + fw/2 + 1.6, board_y0 - 2.5, board_y0 - 0.3, board_shelf_z - 0.01, board_z0 + 0.8);
            box(board_x - 6, board_x + 6, y_bi - 6, y_bi + 0.01, board_z0 + board_t + usb_h, board_z0 + board_t + usb_h + 2);
        }
        // USB-C opening + outside relief
        translate([board_x, y_bi - 1, usb_z]) rrect_xz(10, 4.4, 1.6, back_t + 2);
        translate([board_x, y_back - 1.6, usb_z]) rrect_xz(13, 8, 3, 3);
        // countersunk screws
        for (p = boss_pts) translate([p[0], 0, p[1]]) {
            translate([0, y_bi - 1, 0]) rotate([-90, 0, 0]) cylinder(d = m3_clear, h = back_t + 2);
            translate([0, y_back + 0.01, 0]) rotate([90, 0, 0]) cylinder(d1 = m3_head, d2 = m3_clear, h = (m3_head - m3_clear)/2);
        }
    }
}

// ---------------------------------------------------------------- OLED clamp (print 2)
module clamp(sx = 1) {
    zb = clamp_post_z[0]; zt = clamp_post_z[1];
    difference() {
        union() {
            // body sits on the posts, 3 mm behind the PCB so it clears parts on the back
            hull() for (z = [zb, zt]) translate([sx*clamp_x, pcb_y1 + 3, z]) rotate([-90, 0, 0]) cylinder(r = 3.5, h = 3);
            // pads that press the PCB's top and bottom edges
            for (z = [oled_z - oled_pcb_h/2 + 1.25, oled_z + oled_pcb_h/2 - 1.25])
                box(sx*clamp_x - 3.5, sx*clamp_x + 3.5, pcb_y1, pcb_y1 + 3.01, z - 1.25 - (z < oled_z ? 1.5 : 0), z + 1.25 + (z > oled_z ? 1.5 : 0));
        }
        for (z = [zb, zt]) translate([sx*clamp_x, pcb_y1, z]) rotate([-90, 0, 0]) cylinder(d = m2_clear, h = 10);
    }
}

// ---------------------------------------------------------------- ghost components
module components() {
    color("#050505") translate([-glass_w/2, glass_y0, oled_z - glass_h/2]) cube([glass_w, glass_t, glass_h]);
    color("#0f3d2e") translate([-oled_pcb_w/2, pcb_y0, oled_z - oled_pcb_h/2]) cube([oled_pcb_w, oled_pcb_t, oled_pcb_h]);
    color("#f2f2f2") translate([active_dx - 30, glass_y0 - 0.05, oled_z + active_dz - 5]) cube([60, 0.1, 10]);  // "lit pixels"
    color("#444") translate([-7.5, switch_y - 7.5, shelf_top - 2.2 - choc_plate_t]) cube([15, 15, 2.2 + choc_plate_t + 3]);
    color("ivory") translate([-2.5, switch_y - 1.5, shelf_top + 3]) cube([5, 3, choc_above_plate - 3]);
    color("darkslateblue") translate([board_x - board_w/2, board_y0, board_z0]) cube([board_w, board_l, board_t]);
    color("silver") translate([board_x - 4.5, board_y1 - 6.5, board_z0 + board_t]) cube([9, 6.5 + usb_overhang, usb_h]);
}

// ---------------------------------------------------------------- views
module assembly(e = 0) {
    color("#e6e6e3") shell();
    color("#18181b") translate([0, -1.2*e, 0]) bezel();
    color("#18181b") translate([0, 0, 2*e]) bar();
    color("#d4d4d0") translate([0, 2*e, 0]) back();
    color("#9a9a96") for (sx = [-1, 1]) translate([0, e, 0]) clamp(sx);
    if (show_components && e == 0) components();
}

// print orientations (everything ends up sitting on z = 0)
module print_part(p) {
    if (p == "shell") translate([0, 0, D/2]) rotate([90, 0, 0]) shell();                       // front face down
    if (p == "bezel") translate([0, 0, D/2]) rotate([90, 0, 0]) translate([0, 0, -oled_z]) bezel();
    if (p == "bar")   translate([0, 0, H + bar_proud]) rotate([180, 0, 0]) translate([0, -(bar_y0 + bar_y1)/2, 0]) bar();
    if (p == "back")  translate([0, 0, D/2]) rotate([-90, 0, 0]) translate([0, 0, -H/2]) back(); // outside face down
    if (p == "clamp") translate([0, 0, pcb_y1 + 6]) rotate([-90, 0, 0]) translate([-clamp_x, 0, -oled_z]) clamp(1);
}

if (part == "assembly") assembly(0);
else if (part == "exploded") assembly(14);
else if (part == "print_all") {
    print_part("shell");
    translate([0, H + 12, 0]) print_part("back");
    translate([0, -H - 35, 0]) print_part("bezel");
    translate([0, -H - 95, 0]) print_part("bar");
    translate([W/2 + 25, -10, 0]) print_part("clamp");
    translate([W/2 + 45, -10, 0]) print_part("clamp");
}
else print_part(part);
