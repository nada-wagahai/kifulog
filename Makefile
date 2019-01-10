PROTO_MODULES = api kifu account
PROTO_SRCS = $(foreach n, $(PROTO_MODULES), proto/$n.proto)
GATEWAY_MODULES = api
GATEWAY_SRCS = $(foreach n, $(GATEWAY_MODULES), proto/$n.proto)

PROTO_INCLUDES = -I. -I$(GOPATH)/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis

.PHONY: proto setup proto_pb proto_gw

default:
	@echo $(PROTO_SRCS)

proto: proto_pb proto_gw

proto_pb:
	@for f in $(PROTO_SRCS); do \
		protoc $(PROTO_INCLUDES) --go_out=plugins=grpc:$(GOPATH)/src $$f; \
	done

proto_gw:
	@for f in $(GATEWAY_SRCS); do \
		protoc $(PROTO_INCLUDES) --grpc-gateway_out=logtostderr=true:$(GOPATH)/src $$f; \
	done

setup:
	go get -u github.com/golang/protobuf/protoc-gen-go
	go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway