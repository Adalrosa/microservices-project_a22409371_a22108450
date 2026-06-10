package com.ecommerce.order_service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

@Service
public class SqsPublisher {

    private final SqsClient sqsClient;

    @Value("${aws.sqs.queue-url}")
    private String queueUrl;

    public SqsPublisher(SqsClient sqsClient) {
        this.sqsClient = sqsClient;
    }

    public void publishOrderCreated(Order order) {
        String message = String.format(
                "{\"orderId\": %d, \"productId\": %d, \"quantity\": %d, \"status\": \"%s\"}",
                order.getId(), order.getProductId(), order.getQuantity(), order.getStatus()
        );

        sqsClient.sendMessage(SendMessageRequest.builder()
                .queueUrl(queueUrl)
                .messageBody(message)
                .build());
    }
}