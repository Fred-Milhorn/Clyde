MLTON ?= mlton
BUILD := build

VARSMK := $(BUILD)/vars.mk

$(VARSMK): Project.toml tools/toml2mk.py
	@mkdir -p $(BUILD)
	@tools/toml2mk.py Project.toml > $(VARSMK)

-include $(VARSMK)

MLTON_COMMON_FLAGS ?=
MLTON_DEV_FLAGS    ?=
MLTON_PROD_FLAGS   ?=
BINS               ?=
PROFILES           ?=

.PHONY: all dev prod test clean run help

all: prod

define GEN_BIN_RULES
$$(BUILD)/$$(call up,$(1))-$$(p): $$($(call up,$(1))_MLB_$(p)) | $$(BUILD)
	$$(MLTON) $$(MLTON_COMMON_FLAGS) $$(if $$(filter dev,$(p)),$$(MLTON_DEV_FLAGS),$$(if $$(filter prod,$(p)),$$(MLTON_PROD_FLAGS),)) -output $$@ $$<

.PHONY: $(1)-$(p)
$(1)-$(p): $$(BUILD)/$$(call up,$(1))-$$(p)
	@true
endef

$(BUILD):
	@mkdir -p $(BUILD)

up = $(shell echo $(1) | tr a-z A-Z | tr - _)

$(foreach b,$(BINS),\
  $(eval PROFILE_LIST_$b := $($(call up,$(b))_PROFILES)) \
  $(foreach p,$(PROFILE_LIST_$(b)),\
    $(eval $(call GEN_BIN_RULES,$(b),$(p)))\
  )\
)

dev: $(foreach b,$(BINS),$(b)-dev)
prod: $(foreach b,$(BINS),$(b)-prod)

BIN ?= $(word 1,$(BINS))
PROFILE ?= prod
run: $(BUILD)/$(BIN)-$(PROFILE)
	$< $(ARGS)

test: $(foreach b,$(BINS),$(b)-test)
	@set -e; \
	for exe in $(foreach b,$(BINS),$(BUILD)/$(call up,$(b))-test); do \
		"$$exe"; \
	done

clean:
	rm -rf $(BUILD)

help:
	@echo "Targets:"
	@echo "  make dev|prod"
	@echo "  make <bin>-<profile>"
	@echo "  make run BIN=cli PROFILE=dev ARGS='--help'"
