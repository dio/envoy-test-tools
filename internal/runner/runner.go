package runner

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"syscall"
)

type Runner struct {
	ctx    context.Context
	cmd    *exec.Cmd
	binary string
}

func (r *Runner) Run() error {
	err := r.cmd.Start()
	if err != nil {
		return fmt.Errorf("failed to start %s: %w", r.binary, err)
	}

	if err = r.cmd.Wait(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			waitStatus, _ := exitError.Sys().(syscall.WaitStatus)
			if waitStatus.Signaled() {
				fmt.Println("process was signalled to shutdown")
			}
			return nil
		}
		return fmt.Errorf("failed to launch %s: %v", r.binary, err)
	}
	return nil
}

func New(ctx context.Context, binary string, args []string, out io.Writer) (*Runner, func(error)) {
	cmd := exec.CommandContext(ctx, binary, args...) //nolint:gosec
	cmd.Stdin = os.Stdin

	if out == nil {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	} else {
		// Allow to override the default stdout and stderr, for example by an io.MultiWriter().
		cmd.Stdout = out
		cmd.Stderr = out
	}

	return &Runner{
			ctx:    ctx,
			cmd:    cmd,
			binary: binary,
		}, func(error) {
			_ = cmd.Wait() // to make sure we are done.
		}
}
