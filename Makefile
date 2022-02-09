include Tools.mk
include Version.mk

# Root dir returns absolute path of current directory. It has a trailing "/".
root_dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Local cache directory.
CACHE_DIR ?= $(root_dir).cache

# Go tools directory holds the binaries of Go-based tools.
go_tools_dir       := $(CACHE_DIR)/tools/go
bazel_cache_dir    := $(CACHE_DIR)/bazel
envoy_dir          := $(CACHE_DIR)/envoy
test_tools_bin_dir := $(envoy_dir)/bazel-bin/test/tools

# Currently we resolve it using which. But more sophisticated approach is to use infer GOROOT.
go     := $(shell which go)
goarch := $(shell $(go) env GOARCH)
goos   := $(shell $(go) env GOOS)

export PATH            := $(prepackaged_tools_dir)/bin:$(PATH)
export LLVM_PREFIX     := $(prepackaged_tools_dir)
export RT_LIBRARY_PATH := $(prepackaged_tools_dir)/lib/clang/$(clang_version)/lib/$(goos)
export BAZELISK_HOME   := $(CACHE_DIR)/tools/bazelisk
export CGO_ENABLED     := 0

bazel := GOARCH=amd64 $(go) run $(bazelisk@v) --output_user_root=$(bazel_cache_dir)

# Envoy test tools targets.
config_load_check_tool := $(test_tools_bin_dir)/config_load_check/config_load_check_tool.stripped
router_check_tool      := $(test_tools_bin_dir)/router_check/router_check_tool.stripped
schema_validator_tool  := $(test_tools_bin_dir)/schema_validator/schema_validator_tool.stripped

build: $(config_load_check_tool) $(router_check_tool) $(schema_validator_tool)

$(config_load_check_tool): $(envoy_dir)
	$(call bazel-build,//test/tools/config_load_check:config_load_check_tool.stripped)

$(router_check_tool): $(envoy_dir)
	$(call bazel-build,//test/tools/router_check:router_check_tool.stripped)

$(schema_validator_tool): $(envoy_dir)
	$(call bazel-build,//test/tools/schema_validator:schema_validator_tool.stripped)

define bazel-build
	$(call bazel-dirs)
	cd $(envoy_dir) && $(bazel) build --define wasm=disabled --compilation_mode opt $1
endef

# To make sure the bazel cache directory is created.
define bazel-dirs
	mkdir -p $(BAZELISK_HOME) $(bazel_cache_dir)
endef

$(envoy_dir):
	@git clone --depth 1 -b $(ENVOY_VERSION) https://github.com/envoyproxy/envoy.git $(envoy_dir)
