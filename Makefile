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
$$(BUILD)/$$($(call up,$(1))_OUT_NAME)-$$(p): $$($(call up,$(1))_MLB_$(p)) | $$(BUILD)
	$$(MLTON) $$(MLTON_COMMON_FLAGS) $$(if $$(filter dev,$(p)),$$(MLTON_DEV_FLAGS),$$(if $$(filter prod,$(p)),$$(MLTON_PROD_FLAGS),)) -output $$@ $$<

.PHONY: $($(call up,$(1))_OUT_NAME)-$(p)
$($(call up,$(1))_OUT_NAME)-$(p): $$(BUILD)/$$($(call up,$(1))_OUT_NAME)-$$(p)
	@true
endef

$(BUILD):
	@mkdir -p $(BUILD)

up = $(shell echo $(1) | tr a-z A-Z | tr - _)
out = $($(call up,$(1))_OUT_NAME)

$(foreach b,$(BINS),\
  $(eval PROFILE_LIST_$b := $($(call up,$(b))_PROFILES)) \
  $(foreach p,$(PROFILE_LIST_$(b)),\
    $(eval $(call GEN_BIN_RULES,$(b),$(p)))\
  )\
)

dev: $(foreach b,$(BINS),$(call out,$(b))-dev)
prod: $(foreach b,$(BINS),$(call out,$(b))-prod)

BIN ?= $(word 1,$(BINS))
BIN_OUT ?= $(call out,$(BIN))
PROFILE ?= prod
run: $(BUILD)/$(BIN_OUT)-$(PROFILE)
	$< $(ARGS)

test: $(foreach b,$(BINS),$(call out,$(b))-test)
	@set -e; \
	for exe in $(foreach b,$(BINS),$(BUILD)/$(call out,$(b))-test); do \
		"$$exe"; \
	done

clean:
	rm -rf $(BUILD)

help:
	@echo "Targets:"
	@echo "  make dev|prod"
	@echo "  make clide-dev|clide-prod|clide-test"
	@echo "  make run BIN=$(word 1,$(BINS)) PROFILE=dev ARGS='--help'"
