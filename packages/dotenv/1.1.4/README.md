# dotenv

Loads environment variables from a `.env` file into MATLAB at runtime, so
you can keep API keys and passwords out of source control. Thin port of
the [motdotla/dotenv](https://github.com/motdotla/dotenv) pattern.

- Upstream: https://github.com/mathworks/dotenv-for-MATLAB
- Author: The MathWorks, Inc.
- Version: 1.1.4

## License

The upstream license is a BSD-3-Clause variant whose third clause limits
the end-user grant to use "in conjunction with MathWorks products and
service offerings." Redistribution is permitted; compliance with the
use restriction is the installer's responsibility. See `license.txt`
for the full text.

## Install

```matlab
mip install dotenv
mip load dotenv
```

## Usage

```matlab
d = dotenv('/path/to/.env');   % or dotenv() to read ./.env
host = d.env.DB_HOST;
pass = d.env.DB_PASS;
```

Missing keys return an empty string rather than erroring.
