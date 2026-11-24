package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/samples/value-server/inventory"
)

type Server struct {
	mu       sync.Mutex
	snapshot leanfran.Value[inventory.Snapshot]
}

func (s *Server) Reserve(amount uint64) (uint64, error) {
	command, err := inventory.NewUInt64Value(amount)
	if err != nil {
		return 0, err
	}
	defer command.Close()

	s.mu.Lock()
	defer s.mu.Unlock()
	next, reply, err := inventory.TransitionValue(s.snapshot.Borrow(), command.Take())
	if err != nil {
		return 0, err
	}
	defer reply.Close()
	s.snapshot.Close()
	s.snapshot = next
	return inventory.ReadUInt64Value(reply), nil
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var amount uint64
	if err := json.NewDecoder(r.Body).Decode(&amount); err != nil {
		http.Error(w, "expected an unsigned quantity", http.StatusBadRequest)
		return
	}
	remaining, err := s.Reserve(amount)
	var rejection *leanfran.ExceptError[inventory.Rejection]
	switch {
	case errors.As(err, &rejection):
		http.Error(w, string(rejection.Value), http.StatusConflict)
	case err != nil:
		http.Error(w, err.Error(), http.StatusInternalServerError)
	default:
		_, _ = fmt.Fprintln(w, remaining)
	}
}

func main() {
	remaining, err := inventory.NewUInt64Value(5)
	if err != nil {
		panic(err)
	}
	snapshot, err := inventory.InitialValue(remaining.Take())
	if err != nil {
		panic(err)
	}
	server := &Server{snapshot: snapshot}
	defer func() { server.snapshot.Close() }()
	for _, amount := range []string{"2", "4", "1"} {
		response := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodPost, "/reserve", strings.NewReader(amount))
		server.ServeHTTP(response, request)
		fmt.Printf("%d %s", response.Code, response.Body)
	}
}
