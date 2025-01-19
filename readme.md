This mod operates entirely through console commands:

`/CTbind [name]` bind the entity under the cursor as a probe (with optional label). cannot be used while a trace is running.

`/CTunbind` unbind the probe under the cursor. cannot be used while a trace is running.

`/CTclear` cancel any running trace and unbind all probes

`/CTshow` mark all bound probes for a short time

`/CTstart` start a trace

`/CTstop` stop a trace and write out a .vcd file to script-output

Traced signals will be truncated to the smallest whole hex digit size that can contain their full range, or to a single bit if possible. Multi-bit signals will trace 0 as `Z` to better highlight pulsed values, and to reflect the no-zeroes nature of circuit wires.

View the resulting file with any VCD waveform viewer, such as: [VaporView](https://github.com/Lramseyer/vaporview) [Surfer](https://surfer-project.org/) [GTKWave](https://gtkwave.sourceforge.net/)