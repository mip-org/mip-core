% Test script for matlab_progressbar.

fprintf('Testing ProgressBar class is on the path...\n');
assert(~isempty(which('ProgressBar')), 'ProgressBar class is not on the MATLAB path');
assert(~isempty(which('progress')), 'progress class is not on the MATLAB path');

fprintf('Testing ProgressBar construction (inactive mode)...\n');
nIter = 10;
b = ProgressBar(nIter, 'IsActive', false, 'Title', 'Test');
assert(isa(b, 'ProgressBar'), 'Constructor did not return a ProgressBar');
assert(b.Total == nIter, sprintf('Total should be %d, got %d', nIter, b.Total));
assert(strcmp(b.Title, 'Test'), 'Title not set correctly');

fprintf('Testing step() increments without error...\n');
for k = 1:nIter
    b.step([], [], []);
end
b.release();

fprintf('Testing progress iterator wrapper...\n');
values = 1:5;
collected = zeros(size(values));
idx = 0;
for v = progress(values, 'IsActive', false)
    idx = idx + 1;
    collected(idx) = v;
end
assert(isequal(collected, values), 'progress iterator did not yield input values');

fprintf('SUCCESS\n');
