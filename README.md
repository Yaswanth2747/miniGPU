# miniGPU
A minimal GPU architecture implemented in Verilog, focusing on vector operations and parallel execution. Built as part of Seasons of Code 2025 (SoC) at IIT Bombay.
![miniGPU Architecture](https://github.com/Yaswanth2747/miniGPU/raw/main/miniGPU.drawio.svg)
You can find the developed components in `src` dir.

---

**Build Notes:**
- Each thread will have its own LSU, ALU, RF, PC_NZP
- keep track of params for global instances, local params defined accordingly only for state description, not to be confused
- making the mem controller a little flexible using the parameters like # consumers, channels, for future scalability or expts.
- each thread is like a multicycle version of a risc cpu, can make it pipelined with addition of some additional temp_rgsts and modifications in scheduler, but only multicycle for no
- added core and toplevel havent been developed yet.
- testbenches added, ongoin tests.
- during the previous stages of this project, Quartus Prime was used for hdl design and synthesis along with Modelsim Altera for Simulation
- Now moving on to a VScode based Verilog environment, in which Icarus Verilog is used for simulation and GTKWave for Waveforms. Synthesis is not taken care of right now.
