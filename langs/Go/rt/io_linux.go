package rt

import (
	"syscall"
	"time"
)

func accessedTime(stat *syscall.Stat_t) time.Time {
	return time.Unix(stat.Atim.Sec, stat.Atim.Nsec)
}

func threadID() uint64 { return uint64(syscall.Gettid()) }
