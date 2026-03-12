% Test finufft mip package
% Verifies finufft1d1 against brute-force DFT

nj = 10;
ms = 15;
tol = 1e-9;
iflag = 1;

x = linspace(-pi, pi - 2*pi/nj, nj);
c_re = sin((1:nj) * 0.7);
c_im = cos((1:nj) * 1.3);

[fk_re, fk_im] = finufft1d1(x, c_re, c_im, iflag, tol, ms);

k_min = -floor(ms / 2);
for idx = 1:ms
    k = k_min + (idx - 1);
    Fk_re = 0;
    Fk_im = 0;
    for j = 1:nj
        phase = k * x(j);
        cp = cos(phase);
        sp = sin(phase);
        Fk_re = Fk_re + c_re(j) * cp - c_im(j) * sp;
        Fk_im = Fk_im + c_re(j) * sp + c_im(j) * cp;
    end
    err_re = abs(fk_re(idx) - Fk_re);
    err_im = abs(fk_im(idx) - Fk_im);
    scale = max(abs(Fk_re) + abs(Fk_im), 1e-15);
    assert((err_re + err_im) / scale < 1e-6);
end

disp('SUCCESS')
