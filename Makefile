PROJECT_NAME = picosoc
PREFIX ?= ~/opt
DB_DIR = ${PREFIX}/nextpnr/prjxray-db
CHIPDB_DIR = ${PREFIX}/nextpnr/xilinx-chipdb
XRAY_DIR ?= ${PREFIX}/prjxray
SHELL = /bin/bash
PYTHONPATH ?= ${XRAY_DIR}

ifeq (${BOARD}, qmtech)
PART = xc7k325tffg676-1
FREQ = --freq 50
else ifeq (${BOARD}, genesys2)
PART = xc7k325tffg900-2
PROG = openFPGALoader --cable digilent --bitstream picosoc.bit --ftdi-channel 1
else
.PHONY: check
check:
	@echo "BOARD environment variable not set. Available boards:"
	@echo " * qmtech"
	@echo " * genesys2"
	@exit 1
endif

.PHONY: all
all: ${PROJECT_NAME}.bit
	${PROG}

${PROJECT_NAME}.json: ${BOARD}.v picosoc_noflash.v picorv32.v progmem.v simpleuart.v
	yosys -p "synth_xilinx -flatten -abc9 -arch xc7 -top top; write_json ${PROJECT_NAME}.json" $^

${PROJECT_NAME}.fasm: ${PROJECT_NAME}.json
	nextpnr-xilinx ${FREQ} --chipdb ${CHIPDB_DIR}/${PART}.bin --xdc ${PROJECT_NAME}-${BOARD}.xdc --json $< --write ${PROJECT_NAME}_routed.json --fasm $@

${PROJECT_NAME}.frames: ${PROJECT_NAME}.fasm
	@. "${XRAY_DIR}/utils/environment.sh"
	fasm2frames --part ${PART} --db-root ${DB_DIR}/kintex7 $< > $@

${PROJECT_NAME}.bit: ${PROJECT_NAME}.frames
	@. "${XRAY_DIR}/utils/environment.sh"
	xc7frames2bit --part_file ${DB_DIR}/kintex7/${PART}/part.yaml --part_name ${PART} --frm_file $< --output_file $@

.PHONY: clean
clean:
	@rm -f *.bit
	@rm -f *.frames
	@rm -f *.fasm
	@rm -f *.json
