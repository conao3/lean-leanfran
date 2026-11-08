STEPS := 01-functions 02-theorems 03-structures 04-inductives 05-collections 06-imports 07-io \
	08-polymorphic 09-lake-project 10-ensures 11-prop-specs 12-requires 13-refines 14-loops \
	15-structs-enums 16-opaque 17-generics
VERIFY_STEPS := 10-ensures 11-prop-specs 12-requires 13-refines 14-loops 15-structs-enums \
	16-opaque 17-generics

.PHONY: test
test:
	for s in $(STEPS); do $(MAKE) -C $$s test || exit 1; done

.PHONY: verify
verify:
	for s in $(VERIFY_STEPS); do $(MAKE) -C $$s verify || exit 1; done
