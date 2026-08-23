# xc7bit2bin

## Background

This repository provides a command line utility called `bit2bin`, to
convert FPGA bitstreams from the `.bit`
format into the `.bin` format.


## Usage


To build the program for your machine, simply run:

```bash
make
```

### Using xc7bit2bin

The program reads from the standard input, and writes to the standard output.
For example, running it in the shell:

```bash
xc7bit2bin < input-file.bit > output-file.bin
```

## License

This program is distributed under the MIT License.
