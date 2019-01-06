package rpc

import (
	"context"
	"log"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	dblib "github.com/nada-wagahai/kifulog/go/lib/db"
	apipb "github.com/nada-wagahai/kifulog/go/proto/api"
	kifupb "github.com/nada-wagahai/kifulog/go/proto/kifu"
)

type server struct {
	db dblib.DB
}

func NewServer(db dblib.DB) *server {
	return &server{db: db}
}

func (s *server) Index(context.Context, *apipb.IndexRequest) (*apipb.IndexResponse, error) {
	return &apipb.IndexResponse{
		Entries: []*apipb.IndexResponse_Entry{
			{Id: "kifu_id", Kifu: &kifupb.Kifu{}},
		},
		RecentComments: []*apipb.Comment{},
	}, nil
}

func (s *server) Kifu(ctx context.Context, req *apipb.KifuRequest) (*kifupb.Kifu, error) {
	// TODO authenticate

	if len(req.KifuId) == 0 {
		return nil, status.Errorf(codes.NotFound, "kifu not found")
	}

	kifu, err := s.db.GetKifu(req.KifuId)
	if err != nil {
		if err == dblib.ErrKeyNotFound {
			return nil, status.Errorf(codes.NotFound, "kifu not found")
		}
		return nil, status.Errorf(codes.Internal, "db.GetKifu: %v", err)
	}

	return kifu, nil
}

func (s *server) Board(context.Context, *apipb.BoardRequest) (*apipb.BoardResponse, error) {
	log.Panic("not implemented")
	return nil, nil
}
