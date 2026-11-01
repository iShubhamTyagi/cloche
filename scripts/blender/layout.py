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

CAV_X0, CAV_X1 = X0 + 0.025, PANEL_X0 - 0.027
CAV_Z0, CAV_Z1 = Z0 + 0.028, Z1 - 0.030
CAV_Y1 = D - 0.025
CAV_XC = (CAV_X0 + CAV_X1) / 2

# Two racks: the upper one carries the tray. Rails are on the side walls at every level.
RACKS = {"Rack1": 0.200, "Rack2": 0.125}   # z of the rack's rod centres
RAIL_LEVELS = (0.125, 0.200, 0.262)
ROD_R, FRAME_ROD_R = 0.0016, 0.0025

ELEMENT_R = 0.0055
ELEMENT_YS = (0.11, 0.27)
ELEMENT_ZS = {"Top": CAV_Z1 - 0.018, "Bottom": CAV_Z0 + 0.018}

TRAY_X0, TRAY_X1 = CAV_XC - 0.155, CAV_XC + 0.155
TRAY_Y0, TRAY_Y1 = 0.075, 0.315
TRAY_DEPTH = 0.018
CAKE_SPACING = 0.072

PANEL_T = 0.008                     # control panel plate, y in [-PANEL_T, 0]
PANEL_XC = (PANEL_X0 + X1) / 2
KNOB_ZS = (DOOR_Z1 - 0.115, DOOR_Z1 - 0.180, DOOR_Z1 - 0.245)
