package com.botscrew;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.util.stream.Stream;

@RequiredArgsConstructor
@SpringBootApplication
public class AlexaSkeletonApplication {

    public static void main(String[] args) {
        SpringApplication.run(AlexaSkeletonApplication.class, args);
    }
}
