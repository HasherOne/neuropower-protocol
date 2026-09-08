# SPI Mode 0 timing (WaveDrom)

Paste into [wavedrom.com](https://wavedrom.com) or a WaveDrom renderer.

```json
{
  "signal": [
    {"name": "CS_N",  "wave": "1.0........1."},
    {"name": "SCLK",  "wave": "0.0nlnlnlnln0."},
    {"name": "MOSI",  "wave": "x.=.=.=.=.=.x.", "data": ["b7", "b6", "b5", "b4", "b3"]},
    {"name": "MISO",  "wave": "x.=.=.=.=.=.x.", "data": ["r7", "r6", "r5", "r4", "r3"]},
    {"name": "SPIKE_IN", "wave": "0...........0."}
  ],
  "edge": [
    "a~b t_SU",
    "c~d t_H"
  ],
  "config": {"hscale": 1}
}
```

Normative numbers: [physical-layer.md](../physical-layer.md) §4.
