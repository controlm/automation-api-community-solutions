package com.botscrew.constant;

public enum UserVariables {

    DEFAULT_VALUE("DEFAULT_VALUE"),

    JOB_NAME("JOB_NAME"),
    FOLDER_NAME("FOLDER_NAME"),
    EVENT_NAME("EVENT_NAME"),
    FILE_NAME("FILE_NAME"),
    RESOURCE("RESOURCE"),
    RESOURCE_WITH_VAL("RESOURCE_WITH_VAL"),
    EVENT_VALUE("EVENT_VALUE"),
    RESOURCE_VALUE("RESOURCE_VALUE"),
    JOB_STATUS_NAME("JOB_STATUS_NAME"),
    FILE_NAME_DEPLOY("FILE_NAME_DEPLOY"),
    EVENT_WITH_VAL_NAME("EVENT_WITH_VAL_NAME");

    private String value;

    UserVariables(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
