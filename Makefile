IPA ?= $(firstword $(wildcard ipa/*.ipa))

.PHONY: build tweak clean

build:
	@test -n "$(IPA)" || (echo "Pass IPA=/path/to/decrypted-YouTube.ipa" >&2; exit 1)
	./scripts/pipeline.sh "$(IPA)"

tweak:
	$(MAKE) -C tweak clean package

clean:
	rm -rf out
	$(MAKE) -C tweak clean
