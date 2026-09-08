# NeuroPower — Verilator builds
# Usage:
#   make -C sim/verilator test-golden
#   make -C sim/verilator test-train
#   make -C sim/verilator test-spi
#   make -C sim/verilator test-soc

ROOT      := $(abspath ../..)
VERILATOR ?= verilator

SPI_RTL   := $(ROOT)/rtl/memory_controller/spi_spike_if.v
SPI_CPP   := $(abspath sim_main.cpp)
SPI_TOP   := spi_spike_if
SPI_ODIR  := obj_dir_spi
SPI_EXE   := $(SPI_ODIR)/V$(SPI_TOP)

SOC_N     ?= 16
SOC_RTL   := \
	$(ROOT)/rtl/spike_accelerator/lif_neuron.v \
	$(ROOT)/rtl/spike_accelerator/lif_array.v \
	$(ROOT)/rtl/memory_controller/weight_loader.v \
	$(ROOT)/rtl/core/power_ctrl.v \
	$(ROOT)/rtl/core/np_mmio.v \
	$(ROOT)/rtl/core/neuropower_soc.v
SOC_CPP   := $(abspath sim_soc_main.cpp)
SOC_TOP   := neuropower_soc
SOC_ODIR  := obj_dir_soc
SOC_EXE   := $(SOC_ODIR)/V$(SOC_TOP)
SOC_G     := -GNP_N=$(SOC_N) -GTHR_RESET=4 -GIDLE_CYCLES=100
SW_C      := $(ROOT)/sw/runtime/neuropower.c

CFLAGS_SPI := -std=c++17
CFLAGS_SOC := -std=c++17 -DNP_N=$(SOC_N) -I$(ROOT)/sw/runtime

.PHONY: all lint lint-spi lint-soc test test-golden test-train test-power test-spi test-soc clean

all: $(SPI_EXE) $(SOC_EXE)

$(SPI_EXE): $(SPI_RTL) $(SPI_CPP)
	$(VERILATOR) -Wall --cc --exe --build -Wno-fatal -Mdir $(SPI_ODIR) \
		-CFLAGS "$(CFLAGS_SPI)" --top-module $(SPI_TOP) $(SPI_RTL) $(SPI_CPP)

$(SOC_EXE): $(SOC_RTL) $(SOC_CPP) $(SW_C) $(ROOT)/sw/runtime/neuropower.h
	$(VERILATOR) -Wall --cc --exe --build -Wno-fatal -Mdir $(SOC_ODIR) \
		-CFLAGS "$(CFLAGS_SOC)" $(SOC_G) --top-module $(SOC_TOP) \
		$(SOC_RTL) $(SOC_CPP) $(SW_C)

lint: lint-spi lint-soc

lint-spi:
	$(VERILATOR) --lint-only -Wall -Wno-fatal --top-module $(SPI_TOP) $(SPI_RTL)

lint-soc:
	$(VERILATOR) --lint-only -Wall -Wno-fatal $(SOC_G) --top-module $(SOC_TOP) $(SOC_RTL)

test-golden:
	python3 test_crc_golden.py || python test_crc_golden.py
	python3 test_lif_golden.py || python test_lif_golden.py
	python3 test_weight_loader_golden.py || python test_weight_loader_golden.py

test-train:
	python3 $(ROOT)/sw/examples/keyword_spotting_train.py --np-n $(SOC_N) --min-acc 0.90 \
		|| python $(ROOT)/sw/examples/keyword_spotting_train.py --np-n $(SOC_N) --min-acc 0.90

test-power:
	python3 $(ROOT)/sim/power_trace/event_power.py || python $(ROOT)/sim/power_trace/event_power.py

test-spi: $(SPI_EXE)
	./$(SPI_EXE)

test-soc: $(SOC_EXE)
	./$(SOC_EXE)

test: test-golden test-train test-power test-spi test-soc

clean:
	rm -rf $(SPI_ODIR) $(SOC_ODIR) obj_dir *.vcd
