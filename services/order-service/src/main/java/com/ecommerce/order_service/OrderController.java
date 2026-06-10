package com.ecommerce.order_service;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/orders")
public class OrderController {

    private final OrderRepository repository;
    private final SqsPublisher sqsPublisher;

    public OrderController(OrderRepository repository, SqsPublisher sqsPublisher) {
        this.repository = repository;
        this.sqsPublisher = sqsPublisher;
    }

    @GetMapping
    public List<Order> getAllOrders() {
        return repository.findAll();
    }

    @PostMapping
    public Order createOrder(@RequestBody Order order) {
        Order saved = repository.save(order);
        sqsPublisher.publishOrderCreated(saved);
        return saved;
    }

    @GetMapping("/{id}")
    public ResponseEntity<Order> getOrder(@PathVariable Long id) {
        return repository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}