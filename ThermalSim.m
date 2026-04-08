function [outputArg1,outputArg2] = PowerSim(time,sat_xyz, sun_xyz, opMode)
%POWERSIM Summary of this function goes here
%   INPUTS:
%   time (float): time elapsed since the start of the simulation in seconds
%   sat_xyz (1x3 float array): EarthFixed XYZ vector of the satellite
%   sun_xyz (1x3 float array): EarthFixed XYZ vector of the Sun
%   opMode (int): 1 - safe mode, 2 - nominal mode, 3 - peak mode [SUBJECT
%   TO CHANGE]
%   ADDITIONALLY: There is a text file in the github that has eclipse data
%   that you can parse using claude or something to get eclipse data
%   easier.
%
%   OUTPUTS:
%   You should output any data needed to make a plot in the main file.
%
%   Using these inputs you should generate any relevant plots you come up
%   with. The output of this function needs to be the data you need updated
%   each time step to display in an animation. The animation will be in the
%   main function.
end

