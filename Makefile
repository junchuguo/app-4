###############################################################################
#                            Protocol Buffer targets                          #
###############################################################################
.PHONY: pb
pb:
	@bash ./build/pb_generate.sh -e project

.PHONY: doc
doc:
	@bash ./build/doc_generate.sh -e project

.PHONY: dk-pb
dk-pb:
	@bash ./build/pb_generate.sh -e docker

.PHONY: dk-doc
dk-doc:
	@bash ./build/doc_generate.sh -e docker

.PHONY: lc-pb
lc-pb:
	@bash ./build/pb_generate.sh -e local

.PHONY: lc-doc
lc-doc:
	@bash ./build/doc_generate.sh -e local

###############################################################################
#                       Build and Run project targets                         #
###############################################################################
#-------------------------------Run in process--------------------------------#
.PHONY: build
build:
	@bash ./build/build.sh -e project

.PHONY: dk-build
dk-build:
	@bash ./build/build.sh -e docker

.PHONY: lc-build
lc-build:
	@bash ./build/build.sh -e local

.PHONY: run
run: build lint coverage
	@echo "start server locally"
	@cd ./target/$(PROJECT_NAME)/ ; sh ./scripts/start.sh

.PHONY: lc-run
lc-run: lc-build lc-lint lc-coverage
	@echo "start server locally"
	@cd ./target/$(PROJECT_NAME)/ ; sh ./scripts/start.sh

.PHONY: dep
dep:
	@echo "Download dependencies"
	@go mod tidy
	@go mod download
	@go mod vendor

#-------------------------------Run in docker---------------------------------#
.PHONY: dk-run
dk-run: dk-image
	@echo "run docker images"
	docker run -p ${GRPC_PORT}:${GRPC_PORT} -p ${SWAGGER_PORT}:${SWAGGER_PORT} -p ${HTTP_PORT}:${HTTP_PORT} -p ${QCLOUDAPI_PORT}:${QCLOUDAPI_PORT} -it csighub.tencentyun.com/pulse-line/${PROJECT_NAME}

.PHONY: dk-image
dk-image:
	@bash ./build/build.sh -a linux -e local
	docker build -t csighub.tencentyun.com/pulse-line/$(PROJECT_NAME) \
		     --build-arg PROJECT_NAME=$(PROJECT_NAME) \
		     --build-arg SWAGGER_PORT=$(SWAGGER_PORT) \
		     --build-arg GRPC_PORT=$(GRPC_PORT) \
		     --build-arg QCLOUDAPI_PORT=$(QCLOUDAPI_PORT) \
		     --build-arg HTTP_PORT=$(HTTP_PORT) .

.PHONY: dk-up
dk-up: dk-image
	@echo "run with docker-compose integrated with [redis,mysql,consul...]"
	@docker-compose up -d

.PHONY: dk-down
dk-down:
	@docker-compose down

###############################################################################
#                       Kubernetes manifests targets                          #
###############################################################################
.PHONY: manifests
manifests:
	@bash ./build/kustomize.sh -e project
	@bash ./build/manifests_rename.sh

.PHONY: dk-manifests
dk-manifests:
	@bash ./build/kustomize.sh -e docker
	@bash ./build/manifests_rename.sh

.PHONY: lc-manifests
lc-manifests:
	@bash ./build/kustomize.sh -e local
	@bash ./build/manifests_rename.sh

###############################################################################
#                              Mock Code targets                              #
###############################################################################
.PHONY: mock
mock:
	@bash ./build/mock_generate.sh -e project

.PHONY: dk-mock
dk-mock:
	@bash ./build/mock_generate.sh -e docker

.PHONY: lc-mock
lc-mock:
	@bash ./build/mock_generate.sh -e local

###############################################################################
#                         Code static check targets                           #
###############################################################################
.PHONY: lint
lint: fmt dep
ifdef GLINT
	@echo "Checking golangci-lint..."
	@./bin/golangci-lint run
else
	@echo "golangci-lint not found in project bin, please run \"make install\""
	@exit 1
endif

.PHONY: lc-lint
lc-lint: fmt dep
ifdef LC_GLINT
	@echo "Checking golangci-lint..."
	@golangci-lint run
else
	@echo "golangci-lint not found in PATH, please run \"make lc-install\""
	@exit 1
endif

###############################################################################
#                            Code Format targets                              #
###############################################################################
.PHONY: fmt
fmt:
	@echo "format code"
	@gofmt -s -w  $$(find . -type f -name '*.go'| grep -v "/vendor/")

###############################################################################
#                                Test targets                                 #
###############################################################################
.PHONY: intgrt-test
intgrt-test: build lint coverage
	@echo "run local integration test "
	@cd ./target/$(PROJECT_NAME)/;nohup ./scripts/start.sh > /tmp/$(PROJECT_NAME)_test.log &
	@cd .;go test -v $$(go list ./...| grep -v /vendor/)
	@cd ./target/$(PROJECT_NAME)/; ./scripts/stop.sh
	@rm /tmp/${PROJECT_NAME}_test.log

.PHONY: dk-intgrt-test
dk-intgrt-test: dk-up
	@go test -v $$(go list ./...| grep -v /vendor/)
	@docker-compose down

.PHONY: unit-test
unit-test:
	@go test -covermode=atomic -count=1  -short $$(go list ./...| grep -v /vendor/)

.PHONY: coverage
coverage:
ifdef GOCOV
	@echo "unit test coverage..."
	@go test -covermode=atomic -count=1  -short $$(go list ./...| grep -v /vendor/) -coverprofile=test_result.out
	@./bin/gocov convert test_result.out | ./bin/gocov report
	@rm test_result.out
else
	@echo "[Warning] gocov not found in project bin, please run \"make install\""
	@go test -covermode=atomic -count=1  -short $$(go list ./...| grep -v /vendor/)
endif

.PHONY: lc-coverage
lc-coverage:
ifdef LC_GOCOV
	@echo "unit test coverage..."
	@go test -covermode=atomic -count=1  -short $$(go list ./...| grep -v /vendor/) -coverprofile=test_result.out
	@gocov convert test_result.out | gocov report
	@rm test_result.out
else
	@echo "[Warning] gocov not found in PATH, please run \"make lc-install\""
	@go test -covermode=atomic -count=1  -short $$(go list ./...| grep -v /vendor/)
endif

###############################################################################
#                         Rainbow configuration targets                       #
###############################################################################
.PHONY: conf
conf:
ifeq ($(RAINBOW_ENABLE),true)
	@echo "rainbow config enabled"
	@./build/rainbow_config_gen.sh
else
	@echo "rainbow config disabled"
	@echo $(RAINBOW_ENABLE)
endif

###############################################################################
# WARNING!!! Following targets should not be run locally.                     #
#	Any questions regarding following targets can be forwarded to pl_helper.  #
#                                     .                                       #
#                                     .                                       #
#                                     .                                       #
#                                     .                                       #
#                                     .                                       #
#                                     .                                       #

###############################################################################
#                                  OCI targets.                               #
###############################################################################
# WARNING!!!                                                                  #
# 	This target should only be called by OCI.                                 #
#   DO NOT run this target locally.                                           #
###############################################################################
.PHONY: ci
ci:
	@echo "Set the image tag for kubernetes manifests"
	@bash ./build/manifests_update_image.sh "ccr.ccs.tencentyun.com/pulse-line-prod/$(PROJECT_NAME)" "$(VERSION)"
	@echo "ci build with vendor"
	@bash ./build/build.sh -e local -v enable
	@echo 'Insert VERSION into generated deployment.yaml for each pipeline'
	@bash ./build/manifests_version_subst.sh
