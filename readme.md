This mod operates entirely through console commands:

`/CTbind [name]` bind the power pole under the cursor as a probe (with optional label). cannot be used while a trace is running.
`/CTunbind` unbind the probe under the cursor. cannot be used while a trace is running.
`/CTclear` cancel any running trace and unbind all probes
`/CTshow` mark all bound probes for a short time
`/CTstart` start a trace
`/CTstop` stop a trace and write out a .vcd file to script-output

Signals that start with a value of zero will trace as `X` until their first recorded event, and returning to zero will trace as `Z`, to better highlight flag-style signals.

View the resulting file with any VCD waveform viewer, such as: [VaporView](https://github.com/Lramseyer/vaporview) [Surfer](https://surfer-project.org/) [GTKWave](https://gtkwave.sourceforge.net/)