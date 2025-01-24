# Test code
This folder holds various pieces of code that test the 8051 board.

The assembler code should assemble under Windows 10 using [ASEM-51 v1.3](https://plit.de/asem-51/download.htm).

The code can be assembled using the simple command:
```
asemw <source-file-name>
```
# 8051 board tests
These bits of code test some functionality on the 8051 board.

## switch1.a51
This is a simple piece of code that tests the ability to separate program space from data space. It outputs a count to the LEDs on an [SC129](https://smallcomputercentral.com/rcbus/sc100-series/sc129-digital-i-o-rc2014/) digital I/O board. When the count reaches 15, the program space and data space are separated and the count should continue.

## switch2.a51
Simialr to switch1.a51 above except that it increments a variable in data space just to prove that the two memories are really separated.  

# RCBus and RC-2014 board test programs
## SC129 Digital I/O Module
The SC129 is a simple digital I/O module available from the [Small Computer Central](https://smallcomputercentral.com/rcbus/sc100-series/sc129-digital-i-o-rc2014/) website.

| File | Description |
| :---- | :---- |
| count.a51 | Simple program to count in binary on the LEDs of an SC129 board. |
| echo.a51 | Simple program to read an SC129 input port and write to its output port. |
