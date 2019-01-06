package rpc

import (
	"context"
	"log"

	apipb "github.com/nada-wagahai/kifulog/go/proto/api"
	kifupb "github.com/nada-wagahai/kifulog/go/proto/kifu"
)

type server struct{}

func NewServer() *server {
	return &server{}
}

func (s *server) Index(context.Context, *apipb.IndexRequest) (*apipb.IndexResponse, error) {
	return &apipb.IndexResponse{
		Entries: []*apipb.IndexResponse_Entry{
			{Id: "kifu_id", Kifu: &kifupb.Kifu{}},
		},
		RecentComments: []*apipb.Comment{},
	}, nil
}

func (s *server) Kifu(context.Context, *apipb.KifuRequest) (*kifupb.Kifu, error) {
	log.Panic("not implemented")

	return nil, nil
}

func (s *server) Board(context.Context, *apipb.BoardRequest) (*apipb.BoardResponse, error) {
	log.Panic("not implemented")
	return nil, nil
}
