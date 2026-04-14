function [chargeLevel, genPower] = PowerSim(time, sat_xyz, sun_xyz, sat_vxyz, opMode)
%POWERSIM Summary of this function goes here
%   INPUTS:
%   time (float): time elapsed since the start of the simulation in seconds
%   sat_xyz (1x3 float array): EarthFixed XYZ vector of the satellite
%   sun_xyz (1x3 float array): EarthFixed XYZ vector of the Sun
%   sat_vxyz (1x3 float array): EarthFixed XYZ velocity vector of the satellite
%   angles  (1x4 float array): Beta angle, euler angle 1, euler angle 2,
%   euler angle 3. [I don't understand this so it's up to you to interpret
%   these values and see if they make sense. The satellite is
%   Earth-oriented]
%       -----> Not used — attitude derived from sat_xyz and sat_vxyz per
%       claude
%   opMode (int): 1 - safe mode, 2 - nominal mode, 3 - peak mode [SUBJECT
%   TO CHANGE]
%   ADDITIONALLY: There is a text file in the github that has eclipse data
%   that you can parse using claude or something to get eclipse data
%   easier.
%
%   OUTPUTS:
%   You should output any data needed to make a plot in the main file.
%   chargeLevel (float): Current Battery level in Wh
%
%   Using these inputs you should generate any relevant plots you come up
%   with. The output of this function needs to be the data you need updated
%   each time step to display in an animation. The animation will be in the
%   main function.

%% ── PERSISTENT STATE ─────────────────────────────────────────────────────
persistent battery_Wh    % Battery energy carried between timesteps (Wh)
persistent prev_time     % Previous timestep for dt calculation (s)
persistent initialized   % First-call flag
 
%% ── INITIALIZATION ───────────────────────────────────────────────────────
if isempty(initialized) || time == 0
    initialized = true;
    battery_Wh  = 85.68;   % Start at 85% SOC = 85.68 Wh since it is a 100 Wh battery
    prev_time   = 0;
end
 
%% ── BATTERY CONSTANTS ────────────────────────────────────────────────────
BAT_CAPACITY_Wh = 100.8;          % 7.0 Ah x 14.4V
SOC_MIN_Wh      = 100.8 * 0.75;   % 75.6 Wh  — 25% DOD floor
SOC_MAX_Wh      = 100.8 * 0.95;   % 95.76 Wh — upper limit
 
%% ── LOAD CONSTANTS ───────────────────────────────────────────────────────
LOAD_SAFE    = 1.530;    % W — OBC 0.525W + PCDU 1.005W
LOAD_NOMINAL = 3.712;    % W — Safe + AX100-RX 0.182W + iADCS avg 2.0W
LOAD_PEAK    = 11.352;   % W — Nominal + iADCS peak + 3.0W + AX100-TX 2.64W
HEATER_W     = 6.0;      % W — BPX heater, runs during eclipse only
 
%% ── SOLAR CONSTANTS ──────────────────────────────────────────────────────
P_CELL_EOL   = 1.2 * 0.695;   % 0.834 W/cell — BOL 1.2W x EOL factor 0.695   
N_CELLS_WING = 18;             % cells per DSP wing, 3 strings x 6 cells       
N_CELLS_BODY = 6;              % cells per body-fixed panel 
Re           = 6378.1363;      % Earth radius (km)
 
%% ── ECLIPSE DETECTION ────────────────────────────────────────────────────
sun_hat      = sun_xyz(:)' / norm(sun_xyz);               % unit vector Earth -> Sun
proj         = dot(sat_xyz(:)', sun_hat);                  % sat projected onto Earth->Sun axis
perp_dist    = norm(sat_xyz(:)' - proj * sun_hat);         % perpendicular distance to that axis
eclipse_flag = (proj < 0) && (perp_dist < Re);             % night side AND within shadow cylinder
 
%% ── BODY FRAME ───────────────────────────────────────────────────────────
z_hat = -sat_xyz(:)' / norm(sat_xyz);      % nadir — Z points toward Earth
x_hat =  sat_vxyz(:)' / norm(sat_vxyz);   % along-track — X points in velocity direction
y_hat = cross(z_hat, x_hat);              % panel normal — Y is cross product of Z and X
y_hat = y_hat / norm(y_hat);              % normalize
x_hat = cross(y_hat, z_hat);              % re-orthogonalize X to clean up any drift
x_hat = x_hat / norm(x_hat);              % normalize
 
%% ── PANEL NORMALS ────────────────────────────────────────────────────────
% Hinge axis runs along X (along-track), so deployed normals tilt in XY
% plane? I mean the Y woudl be normal and X would be along the yeah it
% would im triping
c45 = cos(deg2rad(45));     % 0.7071 — body-fixed panels tilted 45deg from the +Y axis
 
% [ x y z ] 
panel_normals = [ ...
     0,  1,  0;  ...      % all 4 deployed panels
    +c45, -c45, 0 ;  ...  % body-fixed +45deg
    -c45, -c45, 0   ...  % body-fixed -45deg
];

cell_counts = [4*N_CELLS_WING; ...   % all 4 deployed panels combined
               N_CELLS_BODY;   ...   % body-fixed +45deg
               N_CELLS_BODY];        % body-fixed -45deg
 
%% ── SOLAR GENERATION ─────────────────────────────────────────────────────
if eclipse_flag
    genPower = 0;
else
    sun_vec   = sun_xyz(:)' - sat_xyz(:)';    % sat -> Sun vector
    sun_hat_s = sun_vec / norm(sun_vec);       % unit vector
 
    % Project sun vector into body frame
    sun_b = [dot(sun_hat_s, x_hat); ...
             dot(sun_hat_s, y_hat); ...
             dot(sun_hat_s, z_hat)];           % sun direction in body coordinates
 
    cos_inc  = max(0, panel_normals * sun_b);                      % illumination factor per panel, clamped >= 0
    panel_P  = P_CELL_EOL .* cell_counts .* cos_inc;              % power per sub-panel (W)
    genPower = sum(panel_P);                                       % total generation (W)
end
 
%% ── LOAD ─────────────────────────────────────────────────────────────────
switch opMode
    case 1,   loadPower = LOAD_SAFE;
    case 2,   loadPower = LOAD_NOMINAL;
    case 3,   loadPower = LOAD_PEAK;
    otherwise
        loadPower = LOAD_NOMINAL;
        warning('PowerSim: Unknown opMode %d — defaulting to Nominal.', opMode);
end
if eclipse_flag
    loadPower = loadPower + HEATER_W;   % heater on during eclipse
end
 
%% ── BATTERY INTEGRATION ──────────────────────────────────────────────────
dt         = time - prev_time;                                 % actual dt handles non-uniform GMAT steps
prev_time  = time;
battery_Wh = battery_Wh + (genPower - loadPower) * (dt / 3600);
battery_Wh = max(SOC_MIN_Wh, min(SOC_MAX_Wh, battery_Wh));    % clamp to safe limits
chargeLevel = battery_Wh;
 
end