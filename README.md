# miniGPU
A minimal GPU architecture implemented in Verilog, focusing on vector operations and parallel execution. Building as part of Seasons of Code 2025 (SoC) at IIT Bombay.

You can find the developed components in `src` dir.

>This is under progress, come later to see more updates..

**On-going Build Notes:**

- Each thread will have its own LSU, ALU, RF, PC_NZP
- keep track of params for global instances, local params defined accordingly only for state description, not to be confused
- making the mem controller a little flexible using the parameters like # consumers, channels, for future scalability or expts.
- each thread is like a multicycle version of a risc cpu, can make it pipelined with addition of some additional temp_rgsts and modifications in scheduler, but only multicycle for no
- added core and toplevel havent been developed yet.
- testbenches added, ongoin tests.
