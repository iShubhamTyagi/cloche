"""Oven dimensions in metres. Camera looks along +Y, the oven front is y = 0, Z up, floor z = 0."""

W, H, D = 0.52, 0.35, 0.40          # overall incl. feet; 0.35 not the brief's 0.33 so the front reads ~1.4:1 like the reference
FOOT_H = 0.032                      # feet lift the body so the open door's handle clears the floor
X0, X1 = -W / 2, W / 2
Z0, Z1 = FOOT_H, H                  # body shell
PANEL_X0 = 0.162                    # control column starts here (to X1)

DOOR_X0, DOOR_X1 = X0 + 0.008, PANEL_X0 - 0.010
DOOR_Z0, DOOR_Z1 = Z0 + 0.008, Z1 - 0.008
DOOR_T = 0.024                      # door thickness; it sits proud of the front, y in [-DOOR_T, 0]
DOOR_BORDER = 0.020                 # frame width around the glass (sides and bottom)
DOOR_TOP_BAND = 0.042               # thicker top band that carries the handle, as in the reference
HINGE_Y, HINGE_Z = -DOOR_T, DOOR_Z0  # bottom hinge axis (along X)
# The door opens 0..180 degrees like the Duo's hinge: 88 lies flat toward the camera, 180 hangs
# straight down in front of the counter edge. So the oven sits at the counter's front edge.
DOOR_MAX_ANGLE = 180
COUNTER_EDGE_Y = HINGE_Y + 0.002    # counter top (z = 0) runs from here back; nothing in front
COUNTER_T = 0.04

CAV_X0, CAV_X1 = X0 + 0.025, PANEL_X0 - 0.027
CAV_Z0, CAV_Z1 = Z0 + 0.028, Z1 - 0.030
CAV_Y1 = D - 0.025
CAV_XC = (CAV_X0 + CAV_X1) / 2

# Two racks, each its own object carrying its own tray, so either can slide out (-Y) for
# plating. Rack2 sits low enough that a cupcake on Tray2 clears Rack1 (90 mm), and Tray1's
# cupcakes clear the top tubes. Rails are on the side walls at every level (one spare).
RACKS = {"Rack1": 0.200, "Rack2": 0.105}   # z of the rack's rod centres
TRAYS = {"Rack1": ("Tray1", "ABCD"), "Rack2": ("Tray2", "EFGH")}   # tray name, cake slot letters
RAIL_LEVELS = (0.105, 0.200, 0.262)
ROD_R, FRAME_ROD_R = 0.0016, 0.0025

ELEMENT_R = 0.0055
ELEMENT_YS = {"Top": (0.17, 0.30), "Bottom": (0.11, 0.27)}   # top pair set back so they show under the cavity lip
ELEMENT_ZS = {"Top": CAV_Z1 - 0.040, "Bottom": CAV_Z0 + 0.020}   # top tubes clear the door's top band

TRAY_X0, TRAY_X1 = CAV_XC - 0.155, CAV_XC + 0.155
TRAY_Y0, TRAY_Y1 = 0.075, 0.315
TRAY_DEPTH = 0.018
CAKE_SPACING = 0.072

PANEL_T = 0.008                     # control panel plate, y in [-PANEL_T, 0]
PANEL_XC = (PANEL_X0 + X1) / 2
KNOB_ZS = (DOOR_Z1 - 0.115, DOOR_Z1 - 0.180, DOOR_Z1 - 0.245)

ELEMENT_LIGHT_WATTS = 2.0           # area light per tube at full heat (render.set_heat scales it)
ELEMENT_LIGHT_COLOR = (1.0, 0.42, 0.12)
