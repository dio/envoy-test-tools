package archives

import (
	"path/filepath"
	"strings"

	"github.com/codeclysm/extract"
)

var DefaultVersion = "1.21.0-rc0"

type Archive interface {
	Version() string
	BinaryName() string
	BinaryDir() string
	URLPattern() string
	Renamer() extract.Renamer
}

type ConfigLoadCheck struct {
	VersionUsed string
}

func (c *ConfigLoadCheck) Version() string {
	if c.VersionUsed != "" {
		return c.VersionUsed
	}
	return DefaultVersion
}

func (c *ConfigLoadCheck) BinaryName() string {
	return "config_load_check_tool"
}

func (c *ConfigLoadCheck) BinaryDir() string {
	return filepath.Join("versions", c.Version(), "bin")
}

func (c *ConfigLoadCheck) URLPattern() string {
	return "https://github.com/dio/envoy-test-tools/releases/download/v%s/config_load_check_tool_%s_amd64_%s.tar.gz"
}

func (c *ConfigLoadCheck) Renamer() extract.Renamer {
	return func(name string) string {
		baseName := filepath.Base(name)
		if baseName == c.BinaryName()+".stripped" {
			return filepath.Join(c.BinaryDir(), strings.TrimSuffix(baseName, filepath.Ext(baseName)))
		}
		return name
	}
}

type RouterCheck struct{}

type SchemaValidator struct{}
