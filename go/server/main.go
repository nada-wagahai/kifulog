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

	"github.com/grpc-ecosystem/grpc-gateway/runtime"

	dblib "github.com/nada-wagahai/kifulog/go/lib/db"
	"github.com/nada-wagahai/kifulog/go/lib/gateway"
	"github.com/nada-wagahai/kifulog/go/lib/httpx"
	apipb "github.com/nada-wagahai/kifulog/go/proto/api"

	"github.com/nada-wagahai/kifulog/go/server/internal/rpc"
)

var (
	rpcBind  = flag.String("rpc", ":9001", ":$port to bind for rpc")
	httpBind = flag.String("http", ":8081", ":$port to bind for http")

	dbpath = flag.String("dbpath", "data/db", "YAML DB path")
)

func init() {
	log.SetOutput(os.Stderr)

	flag.Parse()
}

func main() {
	listen, err := net.Listen("tcp", *rpcBind)
	if err != nil {
		log.Fatalf("net.Listen: %v", err)
	}
	defer listen.Close()

	s := grpc.NewServer(
		grpc.UnaryInterceptor(rpc.LoggerInterceptor(log.New(os.Stderr, "rpc: ", 0))),
	)

	db, err := dblib.NewYaml(*dbpath)
	if err != nil {
		log.Fatalf("db.NewYaml: %v", err)
	}

	srv := rpc.NewServer(db)
	apipb.RegisterAPIServer(s, srv)

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
	mux.Handle("/api/", rpc.UpdateHTTPHeaderInterceptor(apiMux))

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
