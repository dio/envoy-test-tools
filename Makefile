include Tools.mk
include Version.mk

# Root dir returns absolute path of current directory. It has a trailing "/".
root_dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Local cache directory.
CACHE_DIR ?= $(root_dir).cache

BAZEL_FLAGS ?=

# Go tools directory holds the binaries of Go-based tools.
go_tools_dir          := $(CACHE_DIR)/tools/go
prepackaged_tools_dir := $(CACHE_DIR)/tools/prepackaged
bazel_cache_dir       := $(CACHE_DIR)/bazel
envoy_dir             := $(CACHE_DIR)/envoy
test_tools_bin_dir    := $(envoy_dir)/bazel-bin/test/tools
clang_version         := $(subst github.com/llvm/llvm-project/llvmorg/clang+llvm@,,$(clang@v))

# Currently we resolve it using which. But more sophisticated approach is to use infer GOROOT.
go     := $(shell which go)
goarch := $(shell $(go) env GOARCH)
goos   := $(shell $(go) env GOOS)

export PATH            := $(prepackaged_tools_dir)/bin:$(PATH)
export LLVM_PREFIX     := $(prepackaged_tools_dir)
export RT_LIBRARY_PATH := $(prepackaged_tools_dir)/lib/clang/$(clang_version)/lib/$(goos)
export BAZELISK_HOME   := $(CACHE_DIR)/tools/bazelisk
export CGO_ENABLED     := 0

bazel        := GOARCH=amd64 $(go) run $(bazelisk@v) --output_user_root=$(bazel_cache_dir)
envsubst     := $(go_tools_dir)/envsubst
clang        := $(prepackaged_tools_dir)/bin/clang
llvm-config  := $(prepackaged_tools_dir)/bin/llvm-config

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

# This renders configuration template to build main binary using clang as the compiler.
clang.bazelrc: bazel/clang.bazelrc.tmpl $(llvm-config) $(envsubst)
	@$(envsubst) < $< > $@

define bazel-build
	$(call bazel-dirs)
	cd $(envoy_dir) && $(bazel) build $(BAZEL_FLAGS) --define wasm=disabled --compilation_mode opt $1
endef

# To make sure the bazel cache directory is created.
define bazel-dirs
	mkdir -p $(BAZELISK_HOME) $(bazel_cache_dir)
endef

# Catch all rules for Go-based tools.
$(go_tools_dir)/%:
	@GOBIN=$(go_tools_dir) go install $($(notdir $@)@v)

$(envoy_dir):
	@git clone --depth 1 -b $(ENVOY_VERSION) https://github.com/envoyproxy/envoy.git $(envoy_dir)

# Install clang from https://github.com/llvm/llvm-project. We don't support win32 yet as this script
# will fail.
clang-os                          = $(if $(findstring $(goos),darwin),apple-darwin,linux-gnu-ubuntu-20.04)
clang-download-archive-url-prefix = https://$(subst llvmorg/clang+llvm@,releases/download/llvmorg-,$($(notdir $1)@v))
$(clang):
	@mkdir -p $(dir $@)
	curl -SL $(call clang-download-archive-url-prefix,$@)/clang+llvm-$(clang_version)-x86_64-$(call clang-os).tar.xz | \
		tar xJf - -C $(prepackaged_tools_dir) --strip-components 1
$(llvm-config): $(clang)
