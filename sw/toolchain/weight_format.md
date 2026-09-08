# NeuroPower weight blob (`.npw`)

Little-endian binary used by `model_converter.py`, `flash_tool.py`, and `weight_loader.v`.

| Offset | Size | Field | Notes |
|--------|------|-------|-------|
| 0 | 4 | magic | ASCII `NPW1` |
| 4 | 2 | np_n | Neuron / matrix side length |
| 6 | 2 | thr | Signed threshold (LIF) |
| 8 | 4 | payload_len | Must equal `(np_n * np_n) / 2` |
| 12 | 4 | crc32 | CRC-32 of payload only (poly 0xEDB88320, init 0xFFFFFFFF) |
| 16 | payload_len | weights | Packed INT4, row-major `src * np_n + dst`; low nibble = even dst |

INT4 is two's complement (−8…+7).
