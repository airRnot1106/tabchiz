PROJECT := Tabchiz.xcodeproj
SCHEME := Tabchiz
SIMULATOR := platform=iOS Simulator,name=iPhone 17
SOURCES := Tabchiz TabchizTests
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath build -quiet

.PHONY: generate build test lint format clean

generate:
	xcodegen generate --quiet

build: generate
	$(XCODEBUILD) -destination 'generic/platform=iOS Simulator' build

test: generate
	$(XCODEBUILD) -destination '$(SIMULATOR)' test

lint:
	@status=0; \
	xcrun swift-format lint --strict --recursive --parallel $(SOURCES) || status=1; \
	swiftlint lint --strict --quiet || status=1; \
	exit $$status

format:
	xcrun swift-format format --in-place --recursive --parallel $(SOURCES)
	swiftlint lint --fix --quiet

clean:
	rm -rf build $(PROJECT)
