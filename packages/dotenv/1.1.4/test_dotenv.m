% Test script for dotenv.

fprintf('Testing dotenv class is on the path...\n');
assert(~isempty(which('dotenv')), 'dotenv class is not on the MATLAB path');

fprintf('Writing a temporary .env file...\n');
tmpDir = tempname();
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));
envPath = fullfile(tmpDir, 'sample.env');

fid = fopen(envPath, 'w');
assert(fid ~= -1, 'Could not open temp .env file for writing');
fprintf(fid, '# a comment\n');
fprintf(fid, 'DB_HOST=localhost\n');
fprintf(fid, 'DB_USER=alice\n');
fprintf(fid, 'DB_PASS=s3cret=with=equals\n');
fclose(fid);

fprintf('Loading the .env file via dotenv()...\n');
d = dotenv(envPath);

fprintf('Testing key/value retrieval...\n');
assert(strcmp(d.env.DB_HOST, 'localhost'), ...
    sprintf('DB_HOST should be localhost, got %s', d.env.DB_HOST));
assert(strcmp(d.env.DB_USER, 'alice'), ...
    sprintf('DB_USER should be alice, got %s', d.env.DB_USER));
assert(strcmp(d.env.DB_PASS, 's3cret=with=equals'), ...
    sprintf('DB_PASS did not preserve embedded =, got %s', d.env.DB_PASS));

fprintf('Testing missing key returns empty string...\n');
missing = d.env.DOES_NOT_EXIST;
assert(strcmp(missing, ''), 'Missing key should return empty string');

fprintf('Testing that a missing file raises an error...\n');
errored = false;
try
    dotenv(fullfile(tmpDir, 'nope.env'));
catch ME
    errored = true;
    assert(strcmp(ME.identifier, 'DOTENV:CannotOpenFile'), ...
        sprintf('Unexpected error identifier: %s', ME.identifier));
end
assert(errored, 'dotenv should have errored on a missing file');

fprintf('SUCCESS\n');
