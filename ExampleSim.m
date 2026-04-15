function [output1,output2] = ExampleSim(orbit_params,time,input1,input2,input3, opMode)
%*SIMNAME* Summary of this function goes here
%   INPUTS:
%   time (float): time elapsed since the start of the simulation in seconds
%   input1: 
%   input2: 
%   input3: 
%   opMode (int): 1 - safe mode, 2 - nominal mode, 3 - peak mode [SUBJECT
%   TO CHANGE]
%
%   OUTPUTS:
%   You should output any data needed to make a plot in the main file.
%   inContact (bool): true if satellite is in contact with GS
%
%   Using these inputs you should generate any relevant plots you come up
%   with. The output of this function needs to be the data you need updated
%   each time step to display in an animation. The animation will be in the
%   main function.
persistent cfg initialized;

if nargin == 1
    %% ── INITIALIZATION ─────────────────────────────────────────────────
    if isempty(initialized)
        % Anything inside this block will only run ONCE. Save all constants
        % with the example below.
        % cfg.varname = ___

        % Perform any one-time calculations in here as well and save them
        % to cfg as well
        cfg.temp = 420;
        initialized = true;
        return
    end
else
    if initialized == false
       error('[ERR] Comms sim not initialized')
    end
    % This is where the rest of your code will go.
    % The input will be one time step. Meaning a single snapshot of the
    % sat's position.

    % Example output
    [output1 , output2] = array(0,0);
end
