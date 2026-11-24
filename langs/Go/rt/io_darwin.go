package rt

import (
	"syscall"
	"time"
)

func accessedTime(stat *syscall.Stat_t) time.Time {
	return time.Unix(stat.Atimespec.Sec, stat.Atimespec.Nsec)
}

func threadID() uint64 {
	id, _, err := syscall.RawSyscall(syscall.SYS_THREAD_SELFID, 0, 0, 0)
	if err != 0 {
		return 0
	}
	return uint64(id)
}
