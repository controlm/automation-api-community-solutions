package com.botscrew.constant;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Arrays;
import java.util.Optional;

public enum EnvironmentName {

    @JsonProperty("Default")
    DEFAULT("Default"),
    @JsonProperty("Development")
    DEVELOPMENT("Development"),
    @JsonProperty("Test")
    TEST("Test"),
    @JsonProperty("QA")
    QA("QA"),
    @JsonProperty("Production")
    PRODUCTION("Production"),
    @JsonProperty("Staging")
    STAGING("Staging");

    private String value;

    EnvironmentName(String value){
            this.value = value;
    }
//
    public String getValue() {
        return value;
    }

//    @JsonValue
    public static Optional<EnvironmentName> getEnvironmentNameValue(String value){
        return Arrays.stream(EnvironmentName.values()).filter(e->e.getValue().equals(value)).findFirst();
    }
}
