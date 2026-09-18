.PHONY: build package release test icon

build:
	bash scripts/build.sh

package:
	bash scripts/package.sh

release:
	bash scripts/release.sh

test:
	bash Tests/run-motion-tests.sh
	bash Tests/run-wake-tests.sh

icon:
	python3 scripts/make-icon.py
