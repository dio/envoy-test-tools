package main

import (
	"context"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"time"

	"github.com/dio/envoy-test-tools/internal/archives"
	"github.com/dio/envoy-test-tools/internal/downloader"
	"github.com/dio/envoy-test-tools/internal/runner"
	"github.com/mitchellh/go-homedir"
	"sigs.k8s.io/yaml"
)

const (
	funcEHomeEnvKey = "FUNC_E_HOME"
)

var config string

func main() {
	flag.StringVar(&config, "config", "", "config files")
	flag.Parse()

	if config == "" {
		flag.PrintDefaults()
		os.Exit(1)
	}

	args, err := check(config)
	if err != nil {
		flag.PrintDefaults()
		os.Exit(1)
	}

	funcEHome := os.Getenv(funcEHomeEnvKey)
	if funcEHome == "" {
		home, _ := homedir.Dir()
		funcEHome = filepath.Join(home, ".func-e")
	}

	ctx, stop := context.WithTimeout(context.Background(), 30*time.Second)
	defer stop()

	// Use whatever func-e has downloaded, or download the default one.
	archive := &archives.ConfigLoadCheck{VersionUsed: ""} // TODO(dio): Infer this from func-e.
	binaryPath, err := downloader.DownloadVersionedBinary(ctx, archive, funcEHome)
	if err != nil {
		fmt.Printf("failed to download proxy binary: %v\n", err)
		os.Exit(1)
	}
	binary, _ := runner.New(ctx, binaryPath, args, nil)
	binary.Run()
}

func check(config string) ([]string, error) {
	info, err := os.Stat(config)
	if err != nil {
		return nil, err
	}
	if info.IsDir() {
		return []string{config}, nil
	}
	b, err := os.ReadFile(config)
	if err != nil {
		return nil, err
	}

	tmp, err := ioutil.TempDir("", "check")
	if err != nil {
		return nil, err
	}

	var name string
	if b[0] == '{' {
		name = "check_*.json"
	} else {
		name = "check_*.yaml"
		b, err = yaml.YAMLToJSON(b)
		if err != nil {
			return nil, err
		}
	}
	f, err := os.CreateTemp(tmp, name)
	if err != nil {
		return nil, err
	}
	_, err = f.Write(b)
	return []string{tmp}, err
}
