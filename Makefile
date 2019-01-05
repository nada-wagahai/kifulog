PROTO_MODULES = api kifu
PROTO_SRCS = $(foreach n, $(PROTO_MODULES), proto/$n.proto)

PROTO_INCLUDES = -I. -I$(GOPATH)/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis

.PHONY: proto setup

default:
	@echo $(PROTO_SRCS)

proto:
	@for f in $(PROTO_SRCS); do \
		protoc $(PROTO_INCLUDES) --go_out=plugins=grpc:$(GOPATH)/src $$f; \
	done

setup:
	go get -u github.com/golang/protobuf/protoc-gen-go
	go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
