# ============================================================================
# Makefile for FM Radio sw_ref (test vector generation)
# ============================================================================

CC = gcc
CFLAGS = -Wall -O2 -lm

# Source test file (first 256 IQ samples from usrp.dat)
USRP_DAT    = ../test/usrp.dat
SUBSET_FILE = usrp_subset.dat
TEST_SAMPLES = 256

.PHONY: all clean vectors

all: vectors

# Build the test vector generator
fm_radio_test: fm_radio_test.c
	$(CC) -o $@ $< $(CFLAGS)

# Extract test subset from usrp.dat (256 IQ samples = 1024 bytes)
$(SUBSET_FILE): $(USRP_DAT)
	dd if=$(USRP_DAT) of=$(SUBSET_FILE) bs=1 count=$$(($(TEST_SAMPLES)*4)) 2>/dev/null
	@echo "Created $(SUBSET_FILE) ($$(($(TEST_SAMPLES)*4)) bytes)"

# Generate all test vectors
vectors: fm_radio_test $(SUBSET_FILE)
	./fm_radio_test $(SUBSET_FILE)
	@echo ""
	@echo "Test vectors generated:"
	@ls -la *.txt

# Also generate hex version of subset for $readmemh
hex: $(SUBSET_FILE)
	xxd -p -c 1 $(SUBSET_FILE) | awk '{printf "0x%s\n", $$0}' > usrp_subset.hex
	@echo "Created usrp_subset.hex"

clean:
	rm -f fm_radio_test $(SUBSET_FILE) *.txt *.hex
