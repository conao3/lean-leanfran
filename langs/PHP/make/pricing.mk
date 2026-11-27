CHECK_TARGETS += test-pricing-sample

.PHONY: pricing-fixture test-pricing-sample

samples: test-pricing-sample

PRICING_SAMPLE := samples/pricing
PRICING_OUT := test-out/samples/pricing

pricing-fixture: build
	cd $(PRICING_SAMPLE)/lean && lake build
	mkdir -p $(PRICING_OUT)
	$(PHP_COMPILER) module generate --module-name Pricing \
		--search-path $(PRICING_SAMPLE)/lean/.lake/build/lib/lean --php-namespace 'App\Lean\Pricing' \
		--output-dir $(PRICING_OUT) > $(PRICING_OUT)/summary.json

test-pricing-sample: pricing-fixture
	$(show-php-version)
	diff -ru --exclude=summary.json $(PRICING_SAMPLE)/src/_lean $(PRICING_OUT)
	bash samples/run.sh $(PRICING_SAMPLE) main.php
	php -r 'require "$(PRICING_SAMPLE)/vendor/autoload.php"; exit(Composer\InstalledVersions::isInstalled("cuyz/valinor") ? 1 : 0);'
