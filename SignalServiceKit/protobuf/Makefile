# See README.md in this dir for prerequisite setup.

# This requires protobuf@2.6
OBJC_CMD=protoc \
		--plugin=/usr/local/bin/protoc-gen-objc \
		--proto_path="${HOME}/code/workspace/ows/protobuf-objc/src/compiler/" \
		--proto_path="${HOME}/code/workspace/ows/protobuf-objc/src/compiler/google/protobuf/" \
		--proto_path='./'

# This requires protobuf@3.3 or later.
SWIFT_CMD=protoc \
		--proto_path="${HOME}/code/workspace/ows/protobuf-objc/src/compiler/" \
		--proto_path="${HOME}/code/workspace/ows/protobuf-objc/src/compiler/google/protobuf/" \
		--proto_path='./'

PROTOC=./owsprotoc.py \
        --objc-cmd='${OBJC_CMD}' \
        --swift-cmd='${SWIFT_CMD}'

all: signal_service_proto provisioning_protos fingerprint_protos websocket_protos

signal_service_proto: OWSSignalServiceProtos.proto
	$(PROTOC) --out-dir=../src/Messages/ \
		OWSSignalServiceProtos.proto

provisioning_protos: OWSProvisioningProtos.proto
	$(PROTOC) --out-dir=../src/Devices/ \
		OWSProvisioningProtos.proto

fingerprint_protos: OWSFingerprintProtos.proto
	$(PROTOC) --out-dir=../src/Security/ \
		OWSFingerprintProtos.proto

websocket_protos: WebSocketResources.proto
	$(PROTOC) --out-dir=../src/Network/WebSockets/ \
		WebSocketResources.proto
