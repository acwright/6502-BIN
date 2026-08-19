TARGET = Binary
EIGHTTHREE = BINARY
CONFIG = 6502
LOAD = 0x0800

.PHONY: all build view run woz cf clean

all: build woz cf

build: $(TARGET).asm
	cl65 -t none -C $(CONFIG).cfg -l $(TARGET).lst -o $(TARGET).bin $(TARGET).asm

view:
	hexdump -C $(TARGET).bin

run:
	6502 run --bin $(LOAD)=$(TARGET).bin

woz:
	bin2woz -a $(LOAD) $(TARGET).bin > $(TARGET).woz

cf:
	cffs create $(TARGET).img --size 1M
	mkdir -p .cf
	cp -f $(TARGET).bin .cf/$(EIGHTTHREE).BIN
	cffs add $(TARGET).img .cf/$(EIGHTTHREE).BIN
	rm -rf .cf

clean:
	rm -rf .cf
	rm -f $(TARGET).bin $(TARGET).woz $(TARGET).lst $(TARGET).img
