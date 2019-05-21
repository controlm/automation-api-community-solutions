package com.botscrew.processor.impl;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.PriorityOrdered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.stereotype.Service;

@Service
public class CheckEnvironmentalPostProcessor implements EnvironmentPostProcessor, PriorityOrdered {
    @Override
    public void postProcessEnvironment(ConfigurableEnvironment configurableEnvironment, SpringApplication springApplication) {
        String os = System.getProperty("os.name");

        if (os.toLowerCase().contains("windows") || os.toLowerCase().contains("mac os")) {
            configurableEnvironment.setActiveProfiles("dev");
        } else {
            configurableEnvironment.setActiveProfiles("prod");
        }
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE;
    }
}
