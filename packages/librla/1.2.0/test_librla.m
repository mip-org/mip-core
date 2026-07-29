% Test script for librla.
%
% Exercises the public API: the four randomized sketching routines
% (orth_sketch, qr_sketch, svd_sketch, id_sketch) in tolerance mode, the
% deterministic id_qrpiv, rank mode, and the matrix-free LinearOperator
% interface in both rank and tolerance mode.
rng('default');

% Ill-conditioned Hilbert-type matrix with rapidly decaying singular values.
[I, J] = ndgrid(1:120, 1:80);
A = 1 ./ (I + J - 1);
nrmA = norm(A);
rtol = 1e-10;

fprintf('Testing librla.orth_sketch...\n');
[Q, flag] = librla.orth_sketch(A, rtol);
assert(flag == 0, 'orth_sketch terminated early (flag = %d)', flag);
assert(norm(Q' * Q - eye(size(Q, 2))) < 1e-12, 'orth_sketch basis is not orthonormal');
assert(norm(A - Q * (Q' * A)) < 1e-8 * nrmA, 'orth_sketch range approximation is inaccurate');

fprintf('Testing librla.qr_sketch...\n');
[Qq, R, p] = librla.qr_sketch(A, rtol);
assert(norm(A(:, p) - Qq * R) < 1e-8 * nrmA, 'qr_sketch reconstruction error too large');

fprintf('Testing librla.svd_sketch...\n');
[U, s, V] = librla.svd_sketch(A, rtol);
assert(norm(A - U * diag(s) * V') < 1e-8 * nrmA, 'svd_sketch reconstruction error too large');
sfull = svd(A);
assert(max(abs(s - sfull(1:numel(s)))) < 1e-8 * nrmA, 'svd_sketch singular values are inaccurate');

fprintf('Testing librla.id_sketch...\n');
[k, piv, T] = librla.id_sketch(A, rtol);
assert(k >= 1 && k < size(A, 2), 'id_sketch returned an implausible rank (k = %d)', k);
err = norm(A(:, piv(k+1:end)) - A(:, piv(1:k)) * T);
assert(err < 1e-7 * nrmA, 'id_sketch reconstruction error too large');

fprintf('Testing librla.id_qrpiv...\n');
[k2, piv2, T2] = librla.id_qrpiv(A, rtol);
err2 = norm(A(:, piv2(k2+1:end)) - A(:, piv2(1:k2)) * T2);
assert(err2 < 1e-7 * nrmA, 'id_qrpiv reconstruction error too large');

fprintf('Testing rank mode and LinearOperator...\n');
r = 10;
[~, sr, ~] = librla.svd_sketch(A, r, 'power_iter', 1);
assert(numel(sr) == r, 'rank-mode svd_sketch returned %d singular values, expected %d', numel(sr), r);
Aop = LinearOperator(@(x) A * x, @(x) A' * x, size(A, 1), size(A, 2));
assert(isequal(size(Aop), size(A)), 'LinearOperator reports the wrong size');
[~, so, ~] = librla.svd_sketch(Aop, r);
assert(max(abs(so - sfull(1:r))) < 1e-8 * nrmA, 'matrix-free svd_sketch singular values are inaccurate');

fprintf('Testing matrix-free tolerance mode...\n');
[Ut, st, Vt] = librla.svd_sketch(Aop, rtol);
assert(norm(A - Ut * diag(st) * Vt') < 1e-8 * nrmA, ...
    'matrix-free tolerance-mode svd_sketch reconstruction error too large');
assert(max(abs(st - sfull(1:numel(st)))) < 1e-8 * nrmA, ...
    'matrix-free tolerance-mode svd_sketch singular values are inaccurate');

fprintf('SUCCESS\n');
