function [outputArg1,outputArg2] = CSSim(time,inContact, dataRate, chargeRate, userInput)
%% DISCLAIMER: FUNCTION DOES NOT NEED TO BE IN MATLAB
%CSSIM Summary of this function goes here
%   INPUTS:
%   The time is elapsed seconds since the start of the orbit simulation.
%   It should be used to sync your function to the rest of the teams' functions
%   inContact (bool):   true when comm sim returns in contact
%   dataRate (int):     data rate of comm. sys. in bps
%   chargeRate (float): battery level in Wh
%   userInput  (undefined): The user should be able to do the following
%           1) Type a message to "transmit" to the sat.
%           2) Type a particular message to change the operating mode
%           3) Type a different message to return the operating mode to
%           nominal
%
%   OUTPUTS:
%   opMode (int): The sim should output the operating mode based on user
%   changes
%
%   Using these inputs you should generate any relevant plots you come up
%   with. The output of this function needs to be the data you need updated
%   each time step to display in an animation. The animation will be in the
%   main function. CS guys can make their own GUI however they see fit but
%   it should mesh with the rest of the sims' pretty well.
end

