## MOS6502 Emulator in Delphi ##

This is the Delphi / Pascal port of the C++ implementation for the MOS Technology 6502 CPU by [Gianluca Ghettini](https://github.com/gianlucag/mos6502). The code is written to be more readable than fast, however some minor tricks have been introduced to greatly reduce the overall execution time.

Main features:

 * 100% coverage of legal opcodes
 * decimal mode implemented
 * read/write bus callback
 * jump table opcode selection

# mos6502-delphi #

The port was written with minor changes to the original file: the run(N) function was replaced by a single Step() function - if you need to run more than one cycle, just put that function inside a loop.

# 6502 functional test

The [6502 functional test](https://github.com/Klaus2m5/6502_65C02_functional_tests) (version 16-aug-2013) by Klaus Dormann is included.

# C64 emulator #

A very basic C64 emulator is included. You need to download the BASIC ROM [basic.901226-01.bin](http://www.commodore.ca/manuals/funet/cbm/firmware/computers/c64/basic.901226-01.bin) and the Kernal ROM [kernal.901227-03.bin](http://www.commodore.ca/manuals/funet/cbm/firmware/computers/c64/kernal.901227-03.bin) and put both files inside the ROMs folder. Install the commodore [CBM.ttf](https://github.com/bobsummerwill/VICE/raw/master/data/fonts/CBM.ttf) font found in the VICE package.

The C64 Emulator uses a symbolic keyboard translation thus any keyboard layout should work.

This C64 emulator is just a a very basic 6502/6510 emulation example and is not feature complete. Please take a look at [VICE - Versatile Commodore Emulator](http://vice-emu.sourceforge.net/) instead.

# VIC-20 emulator #

Based on the C64 emulator, a VIC-20 emulator is now included. You need to download the BASIC ROM [basic.901486-01.bin](http://www.commodore.ca/manuals/funet/cbm/firmware/computers/vic20/basic.901486-01.bin) and the Kernal ROM [kernal.901486-07.bin](http://www.commodore.ca/manuals/funet/cbm/firmware/computers/vic20/kernal.901486-07.bin) and put both files inside the ROMs folder. Changes compared to the C64 source are Addr and Keyboard matrix.

