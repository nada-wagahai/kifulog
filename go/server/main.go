package main

import (
	"context"
	"flag"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/grpc-ecosystem/grpc-gateway/runtime"

	"github.com/nada-wagahai/kifulog/go/lib/gateway"
	"github.com/nada-wagahai/kifulog/go/lib/httpx"
	apipb "github.com/nada-wagahai/kifulog/go/proto/api"

	"github.com/nada-wagahai/kifulog/go/server/internal/rpc"
)

var (
	rpcBind  = flag.String("rpc", ":9001", ":$port to bind for rpc")
	httpBind = flag.String("http", ":8081", ":$port to bind for http")
)

func init() {
	log.SetOutput(os.Stderr)

	flag.Parse()
}

func LoggerInterceptor(logger *log.Logger) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		md, ok := metadata.FromIncomingContext(ctx)
		if !ok {
			return nil, status.Error(codes.Internal, "rpc.LoggingInterceptor: No metadata")
		}

		paths := md["grpcgateway-pragma"]
		if len(paths) == 0 {
			return nil, status.Error(codes.Internal, "rpc.LoggingInterceptor: No path in metadata")
		}
		path := paths[0]

		res, err := handler(ctx, req)
		if err != nil {
			logger.Printf("Request error: path=%v error=%v", path, err)
		} else {
			logger.Printf("Request: path=%v", path)
		}

		return res, err
	}
}

// UpdateHTTPHeaderInterceptor is an interceptor to catch Path HTTP parameter
func UpdateHTTPHeaderInterceptor(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Send the path to grpc-gateway in order to have it translate to grpc metadata.
		// TODO Make sure if it is valid to insert a path into Pragma request header.
		r.Header["Pragma"] = []string{r.URL.Path}
		h.ServeHTTP(w, r)
	})
}

func main() {
	listen, err := net.Listen("tcp", *rpcBind)
	if err != nil {
		log.Fatalf("net.Listen: %v", err)
	}
	defer listen.Close()

	s := grpc.NewServer(
		grpc.UnaryInterceptor(LoggerInterceptor(log.New(os.Stderr, "rpc: ", 0))),
	)

	apipb.RegisterAPIServer(s, rpc.NewServer())

	go func() {
		if err := s.Serve(listen); err != nil {
			log.Fatalf("grpc.Serve: %v", err)
		}
	}()
	log.Printf("Start rpc: %v", *rpcBind)

	ctx := context.Background()

	apiMux := runtime.NewServeMux(runtime.WithMarshalerOption("*", &gateway.JSONPb{OrigName: true}))
	opts := []grpc.DialOption{grpc.WithInsecure(), grpc.WithBlock()}
	err = apipb.RegisterAPIHandlerFromEndpoint(ctx, apiMux, "localhost"+*rpcBind, opts)
	if err != nil {
		log.Fatalf("register endpoint failed: %v", err)
	}

	mux := httpx.NewHandler()
	mux.Handle("/api/", UpdateHTTPHeaderInterceptor(apiMux))

	go func() {
		if err := http.ListenAndServe(*httpBind, mux); err != nil {
			log.Fatalf("failed to listen and serve http: %v", err)
		}
	}()
	log.Printf("Start http: %v", *httpBind)

	term := make(chan os.Signal)
	signal.Notify(term, syscall.SIGTERM)
	<-term
	s.GracefulStop()
}
