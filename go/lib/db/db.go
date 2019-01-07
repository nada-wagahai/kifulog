package db

import (
	"fmt"

	accountpb "github.com/nada-wagahai/kifulog/go/proto/account"
	kifupb "github.com/nada-wagahai/kifulog/go/proto/kifu"
)

type DB interface {
	GetKifu(string) (*kifupb.Kifu, error)
	GetSession(string) (*accountpb.Session, error)
}

var (
	ErrKeyNotFound = fmt.Errorf("key not found")
)
