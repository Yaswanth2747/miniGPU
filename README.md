# miniGPU
A minimal GPU architecture implemented in Verilog, focusing on vector operations and parallel execution. Building as part of Seasons of Code 2025 (SoC) at IIT Bombay.


This is under progress, come later to see more updates..

On-going Build Notes:

- Each thread will have its own LSU, ALU, RF, PC_NZP
- maybe there is no need for a scheduler, will see later on
- making the mem controller a little flexible using the parameters like # consumers, channels, for future scalabitly or expts.
