package httpx

import (
	"net/http"
	"sync"
)

// HTTPX is an wrapper interface around http.Handler.
// It handles endpoints for kubernetes lifecycle hooks.
type HTTPX interface {
	http.Handler

	Handle(pattern string, handler http.Handler)
	HandleFunc(pattern string, handler func(http.ResponseWriter, *http.Request))
}

// NewHandler returns a new instance of HTTPX.
func NewHandler(fns ...HandlerOption) HTTPX {
	mux := http.NewServeMux()

	srv := &server{
		mux: mux,
	}

	opts := httpxOptions{
		healthcheckFunc: srv.healthcheckFunc,
	}
	for _, fn := range fns {
		fn(&opts)
	}

	mux.HandleFunc("/healthz", opts.healthcheckFunc)

	return srv
}

// A HandlerOption is an option of HTTPX.
type HandlerOption func(*httpxOptions)

// WithHealthcheck sets healthcheck url.
func WithHealthcheck(f http.HandlerFunc) HandlerOption {
	return func(opt *httpxOptions) {
		opt.healthcheckFunc = f
	}
}

type httpxOptions struct {
	healthcheckFunc http.HandlerFunc
}

type server struct {
	mu       sync.RWMutex
	shutdown bool

	mux *http.ServeMux
}

func (s *server) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	s.mux.ServeHTTP(w, req)
}

func (s *server) Handle(pattern string, handler http.Handler) {
	s.mux.Handle(pattern, handler)
}

func (s *server) HandleFunc(pattern string, handler func(http.ResponseWriter, *http.Request)) {
	s.mux.HandleFunc(pattern, handler)
}

func (s *server) healthcheckFunc(w http.ResponseWriter, req *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.shutdown {
		http.Error(w, "shutting down", http.StatusServiceUnavailable)
	}
}
