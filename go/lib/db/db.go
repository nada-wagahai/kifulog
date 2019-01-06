package db

import (
	"encoding/base64"
	"fmt"
	"os"

	"github.com/golang/protobuf/proto"

	"gopkg.in/yaml.v2"

	kifupb "github.com/nada-wagahai/kifulog/go/proto/kifu"
)

type DB interface {
	GetKifu(string) (*kifupb.Kifu, error)
}

var (
	ErrKeyNotFound = fmt.Errorf("key not found")
)

type yamldb struct {
	path string

	kifu     map[string]string
	board    map[string]string
	account  map[string]string
	session  map[string]string
	comment  map[string]string
	metadata map[string]string
}

func NewYaml(path string) (*yamldb, error) {
	kifu, err := loadDB(path + "/kifu")
	if err != nil {
		return nil, fmt.Errorf("kifu db: %v", err)
	}
	board, err := loadDB(path + "/board")
	if err != nil {
		return nil, fmt.Errorf("board db: %v", err)
	}
	account, err := loadDB(path + "/account")
	if err != nil {
		return nil, fmt.Errorf("account db: %v", err)
	}
	session, err := loadDB(path + "/session")
	if err != nil {
		return nil, fmt.Errorf("session db: %v", err)
	}
	comment, err := loadDB(path + "/comment")
	if err != nil {
		return nil, fmt.Errorf("comment db: %v", err)
	}
	metadata, err := loadDB(path + "/kifu_meta")
	if err != nil {
		return nil, fmt.Errorf("metadata db: %v", err)
	}

	return &yamldb{
		path:     path,
		kifu:     kifu,
		board:    board,
		account:  account,
		session:  session,
		comment:  comment,
		metadata: metadata,
	}, nil
}

func loadDB(path string) (map[string]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	decoder := yaml.NewDecoder(f)

	kv := map[string]string{}
	if err := decoder.Decode(kv); err != nil {
		return nil, err
	}

	return kv, nil
}

func saveDB(file string, db map[string]string) error {
	f, err := os.OpenFile(file, os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer f.Close()

	encoder := yaml.NewEncoder(f)
	defer encoder.Close()

	if err := encoder.Encode(db); err != nil {
		return err
	}

	return nil
}

func (db *yamldb) GetKifu(id string) (*kifupb.Kifu, error) {
	str, ok := db.kifu[id]
	if !ok {
		return nil, ErrKeyNotFound
	}

	buf := &kifupb.Kifu{}
	if err := decode(str, buf); err != nil {
		return nil, err
	}

	return buf, nil
}

func decode(str string, pb proto.Message) error {
	bytes, err := base64.StdEncoding.DecodeString(str)
	if err != nil {
		return err
	}

	if err := proto.Unmarshal(bytes, pb); err != nil {
		return err
	}

	return nil
}

func encode(pb proto.Message) (string, error) {
	bytes, err := proto.Marshal(pb)
	if err != nil {
		return "", err
	}

	return base64.StdEncoding.EncodeToString(bytes), nil
}
