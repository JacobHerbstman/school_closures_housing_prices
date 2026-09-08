.DELETE_ON_ERROR:
.SECONDARY:

../input ../output ../temp ../report:
	mkdir -p $@

../input/%/ ../output/%/ ../temp/%/:
	mkdir -p $@

UPSTREAM_TASK_DIRS := $(patsubst %/code,%,$(wildcard ../../*/code ../../../*/code ../../audits/*/code ../../tasks/*/code ../../tasks/audits/*/code))

.PRECIOUS: ../../% ../../../%
.PHONY: FORCE_UPSTREAM_CHECK

FORCE_UPSTREAM_CHECK:

define UPSTREAM_OUTPUT_RULE
$(1)/output/%: FORCE_UPSTREAM_CHECK
	$$(MAKE) -C $(1)/code ../output/$$*
endef

$(foreach task,$(UPSTREAM_TASK_DIRS),$(eval $(call UPSTREAM_OUTPUT_RULE,$(task))))
