# MON51 Monitor Program
The 8051 monitor program I'm using to get started is Dave Dunfields MON51. Dave has kindly made available 40+ years of source code via [his website](https://dunfield.themindfactory.com/).

I'm not sure what assembler was used to assemble the original assembly code (MON51.ASM). I therefore modified the code so that it would assemble under Windows 10 using [ASEM-51 v1.3](https://plit.de/asem-51/download.htm).

My modified version of MON51 - called MON51.a51 - for my RCBus 8051 board can be assembled using ASEM51 v1.3. I've also included the original copyright information from Dave Dunfield.

The monitor can be assembled using the simple command:
```
asemw mon51
```

The monitor adds LJMP instructions for the exception vectors to handlers starting at address $3000 and the baud rate is set to 38400 baud.

I've added a new Z command. This will set EA low, separate program memory from data memory (so each has its own memory space of almost 64K : $0000 to $F800) and internally reset the 8051 to execute code from external program memory starting at address $0000.
 
The original source code to MON51 can be found in the MONITOR.ZIP file on Dave's website along with MON51.TXT which is a brief user guide.

