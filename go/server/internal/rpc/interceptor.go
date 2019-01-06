package rpc

import (
	"context"
	"log"
	"net/http"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

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
