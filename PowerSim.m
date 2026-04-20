function [chargeLevel, genPower] = PowerSim(orbit_params, time, sat_xyz, sun_xyz, sat_vxyz, opMode, inContact)
%POWERSIM Electrical Power System simulation for OKSat 3U CubeSat
%  using GMAT data, Opertional Mode, and inside the Contact window for
%  inputs. 
%   INPUTS:
%   orbit_params (1x4 float array): [Re, H, incl, e_min]
%       Re   — Earth radius (km)
%       H    — Orbit altitude (km)
%       incl — Inclination (deg)
%       e_min — Min elevation angle (deg, unused here)
%   time (float): time elapsed since simulation start in seconds
%   sat_xyz (1x3 float): ECEF position of satellite (km)
%   sun_xyz (1x3 float): ECEF position of Sun (km)
%   sat_vxyz (1x3 float): ECEF velocity of satellite (km/s)
%   angles (1x4 float): [beta, euler1, euler2, euler3] — NOT USED
%       attitude derived from sat_xyz and sat_vxyz
%   opMode (int): 1 - Safe, 2 - Nominal RX, 3 - Nominal TX, 4 - Peak
%
%   OUTPUTS:
%   chargeLevel (float): Battery state in Wh
%   genPower (float): Solar generation in W
%   
%   ASSUMPTIONS:
%       Some assumptions were explained later in but majority has not. Base
%       assumptions include the following
%           1) Thermal property of the SAT costs too much overhead,
%           so it has been simplified to a time structure
%           2) Modes have been simplifed to usage of TYPICAL component
%           power usage
%           3) ACDS has been simplified to just use given....
%           PEAK is max power of ACDS, Typical is NOMINAL, and SAFE is low
%           power.

persistent cfg initialized battery_Wh prev_time;

if nargin == 1
%% ── INITIALIZATION ───────────────────────────────────────────────────────
    if isempty(initialized)
        cfg.Re          = orbit_params(1);      % Earth radius (km)
        cfg.H           = orbit_params(2);      % Orbit altitude (km)
        cfg.incl        = orbit_params(3);      % Inclination (deg)
        cfg.e_min       = orbit_params(4);      % Min elevation (deg)

        % Battery — GomSpace BPX 100 Wh
        cfg.BAT_CAP_Wh  = 100.8;               % 7.0 Ah x 14.4V nominal
        cfg.SOC_MIN_Wh  = 100.8 * 0.20;        % 20% floor — 20.16 Wh
        cfg.SOC_MAX_Wh  = 100.8 * 0.95;        % 95% upper clamp — 95.76 Wh
        cfg.SOC_INIT_Wh = 100.8 * 0.85;        % 85% starting SOC — 85.68 Wh

        % Loads (W)
        % Base assumptions:
            % > Assuming A3200 OBC is running All clocks 32MHz, running ADCS
            % for all mode concepts
            % > Assuming Typical value for the AX100 Radio
            % > PEAK value is assuming that the iADCS400-15 is just being
            % changed to the 5.0W max for large change 

        cfg.LOAD_SAFE   = 2.24;                % OBC 0.1485W + P60 housekeeping 1.005W + AX100-RX 0.182W + iADCS avg 0.9 W
        cfg.LOAD_NOM    = 6.14;                % Safe + iADCS avg 2.0W (+1.1W) + payload 2.8W (SONY starvis IMX327)
        cfg.LOAD_TX     = 2.64;                % For the Communications Pass AX100-TX 2.64W
        cfg.LOAD_PEAK   = 9.140;               % Nominal + iADCS peak 5W (+3W)
        cfg.HEATER_W    = 6.0;                 % BPX heater, eclipse only

        % Solar — GomSpace DSP 135deg AzurSpace 3G30-Advanced
        cfg.AM0         = 1361.0;              % Solar constant (W/m^2)
        cfg.CELL_AREA   = 30e-4;               % 30 cm^2 per cell
        cfg.EFF_BOL     = 0.298;               % 29.8% BOL efficiency, 3G30-Advanced
        cfg.EFF_DEGRADE = 0.695;               % 5-year EOL degradation factor
        cfg.EFF_MPPT    = 0.90;                % P60 ACU-200 MPPT efficiency
        cfg.P_CELL_EOL  = cfg.AM0 * cfg.CELL_AREA * cfg.EFF_BOL * cfg.EFF_DEGRADE * cfg.EFF_MPPT;
                                               % ~0.761 W/cell at normal incidence EOL
        cfg.N_CELLS_WING = 18;                 % 3 strings x 6 cells per DSP wing
        cfg.N_CELLS_BODY = 6;                  % 6 cells per body-fixed panel

        % For 
        cfg.ORBIT_PERIOD_s     = 5820;         % Aprrox Orbit period
        cfg.ECLISPE_DURATION_s = 2090;         % Approx time in eclispe using Eclipse.txt (Penumbra + Umbra)
        

        battery_Wh  = cfg.SOC_INIT_Wh;
        prev_time   = 0;
        initialized = true;
        chargeLevel = battery_Wh;
        genPower    = 0;
        return
    end
else
    if ~initialized
        error('[ERR] PowerSim not initialized — call PowerSim(orbit_params) first');
    end

%% ── ECLIPSE DETECTION ────────────────────────────────────────────────────
    sun_hat      = sun_xyz(:)' / norm(sun_xyz);               % unit vector Earth -> Sun
    proj         = dot(sat_xyz(:)', sun_hat);                  % sat projected onto Earth->Sun axis
    perp_dist    = norm(sat_xyz(:)' - proj * sun_hat);         % perpendicular distance to shadow axis
    eclipse_flag = (proj < 0) && (perp_dist < cfg.Re);         % cylindrical shadow model

%% ── BODY FRAME ───────────────────────────────────────────────────────────
    z_hat =  sat_xyz(:)' / norm(sat_xyz);      % anti-nadir — +Z points away from Earth
    x_hat =  sat_vxyz(:)' / norm(sat_vxyz);   % along-track — +X points in velocity direction
    y_hat =  cross(z_hat, x_hat);              % cross-track
    y_hat =  y_hat / norm(y_hat);              % normalize
    x_hat =  cross(y_hat, z_hat);              % re-orthogonalize X
    x_hat =  x_hat / norm(x_hat);              % normalize

%% ── PANEL NORMALS ────────────────────────────────────────────────────────
    c45 = cosd(45);                            % 0.7071

    % Normals in body frame [x, y, z], +Z = anti-nadir
    panel_normals = [ ...
         0,     0,    1;  ...    % 4 deployed wings — point anti-nadir
        +c45,   0,  c45;  ...    % body-fixed panel +45deg in X-Z plane
        -c45,   0,  c45   ...    % body-fixed panel -45deg in X-Z plane
    ];

    cell_counts = [4 * cfg.N_CELLS_WING; ...  % 4 deployed wings lumped (approximation)
                   cfg.N_CELLS_BODY;      ...  % body +45deg
                   cfg.N_CELLS_BODY];          % body -45deg

%% ── SOLAR GENERATION ─────────────────────────────────────────────────────
    if eclipse_flag
        genPower = 0;
    else
        sun_vec   = sun_xyz(:)' - sat_xyz(:)';     % sat -> Sun vector
        sun_hat_s = sun_vec / norm(sun_vec);        % unit vector

        % Project sun vector into body frame
        sun_b = [dot(sun_hat_s, x_hat); ...
                 dot(sun_hat_s, y_hat); ...
                 dot(sun_hat_s, z_hat)];            % sun direction in body coordinates

        cos_inc  = max(0, panel_normals * sun_b);                       % illumination per panel, clamped >= 0
        panel_P  = cfg.P_CELL_EOL .* cell_counts .* cos_inc;           % power per panel group (W)
        genPower = sum(panel_P);                                        % total generation (W)
    end

%% ── LOAD ─────────────────────────────────────────────────────────────────
    % Heater Assumption
    time_inOrbit         = mod(time,cfg.ORBIT_PERIOD_s);
    inEclispe_late       = eclispe_flagg && (time_inOrbit > (cfg.ORBIT_PERIOD_S - ECLIPSE_DURATION_S/2));

    % Operitional Modes Load Window
    switch opMode
        case 1
            loadPower = cfg.LOAD_SAFE;
        case 2
            loadPower = cfg.LOAD_NOM;  
        case 3
            loadPower = cfg.LOAD_PEAK;
        otherwise
            loadPower = cfg.LOAD_NOM;
            warning('PowerSim: Unknown opMode %d — defaulting to Nominal RX.', opMode);
    end
    
    if inContact
        loadPower = loadPower + cfg.LOAD_TX;
    end

    if inEclispe_late
        loadPower = loadPower + cfg.HEATER_W;  % BPX heater on during eclipse
    end

%% ── BATTERY INTEGRATION ──────────────────────────────────────────────────
    dt         = time - prev_time;                                          % actual dt, handles non-uniform GMAT steps
    prev_time  = time;
    battery_Wh = battery_Wh + (genPower - loadPower) * (dt / 3600);
    battery_Wh = max(cfg.SOC_MIN_Wh, min(cfg.SOC_MAX_Wh, battery_Wh));    % clamp to safe limits
    chargeLevel = battery_Wh;

end
end
