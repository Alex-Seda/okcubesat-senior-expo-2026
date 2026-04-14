function Gt_dBi = ANT430Gain(az_rad, el_rad)

    phi_deg   = rad2deg(mod(az_rad, 2*pi));
    theta_deg = rad2deg(pi/2 - el_rad);

    phi_rad      = deg2rad(0:359);
    theta_unique = [0; 45; 90; 135; 180];

    G_rings      = zeros(5, 360);
    G_rings(1,:) = 1.40;
    G_rings(2,:) = 0.771;
    G_rings(3,:) = 0.30 * cos(4 * phi_rad);
    G_rings(4,:) = 0.45;
    G_rings(5,:) = 1.25;

    theta_clamped = max(0, min(180, theta_deg(:)));   % (N x 1)
    G_at_phi      = interp1(theta_unique, G_rings, theta_clamped, 'pchip');  % (N x 360)

    phi_wrapped = mod(phi_deg(:), 360);
    G_ext       = [G_at_phi, G_at_phi(:,1)];          % (N x 361)
    phi_lut     = 0:360;

    N      = numel(theta_clamped);
    Gt_dBi = zeros(N, 1);
    for i = 1:N
        Gt_dBi(i) = interp1(phi_lut, G_ext(i,:), phi_wrapped(i), 'pchip');
    end

    Gt_dBi = reshape(Gt_dBi, size(az_rad));
end