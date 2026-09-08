Tutorials
=========

1. Install deps: ``pip install -r sw/requirements.txt``
2. Run goldens: ``make -C sim/verilator test-golden``
3. Train INT4 KWS stand-in: ``python sw/examples/keyword_spotting_train.py``
4. Estimate autonomy: ``python sim/power_trace/event_power.py``
