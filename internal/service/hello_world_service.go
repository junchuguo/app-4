
package service

import (
    "context"
. "oauth2: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@github.com/junchuguo/app-4/api"

)

// Service type
//  Helloworld Service

        type HelloWorldService struct {
            UnimplementedHelloWorldServiceServer
        }

    // Create a new service
        func NewHelloWorldService() *HelloWorldService {
            service := &HelloWorldService{}
            return service
        }

    //  Sends a greeting
        func (service *HelloWorldService) SayHello(ctx context.Context, request *SayHelloRequest) (*SayHelloResponse, error) {
            return &SayHelloResponse{}, nil
        }
        
    