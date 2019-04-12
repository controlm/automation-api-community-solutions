package com.botscrew.constant;

public enum Intent {

    NUMBER_INTENT("NumberIntent"),
    CHOOSE_ENVIRONMENT_INTENT("ChooseEnvironmentIntent"),
    SYMBOL_POSITION("SymbolPosition"),
    NO_INTENT("AMAZON.NoIntent"),
    YES_INTENT("AMAZON.YesIntent"),
    DEFINE_ENVIRONMENT_INTENT("DefineEnvironmentIntent"),
    SPECIAL_SYMBOLS("SpecialSymbols"),
    END_OF_WORD("EndOfWord"),
    LETTER_INTENT("LetterIntent"),
    DEPLOY_INTENT("DeployIntent"),
    CANCEL_INTENT("AMAZON.CancelIntent"),
    FALLBACK_INTENT("AMAZON.FallbackIntent"),
    STOP_INTENT("AMAZON.StopIntent"),
    HELP_INTENT("AMAZON.HelpIntent"),
    RUN_JOB_INTENT("RunJobIntent"),
    CHOOSE_DEFAULT_INTENT("ChooseDefaultIntent"),
    JOB_STATUS_INTENT("JobStatusIntent"),
    VALIDATE_THE_FILE_INTENT("ValidateTheFileIntent"),
    RESOURCE_STATUS_INTENT("ResourceStatusIntent"),
    RESOURCE_TO_VALUE_INTENT("ResourceToValueIntent"),
    EVENT_STATUS_INTENT("EventStatusIntent"),
    SET_EVENT_TO_VALUE_INTENT("SetEventToValueIntent"),
    DEFAULT_ENVIRONMENT_INTENT("SetDefaultEnvironmentIntent");

    private String value;

    Intent(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }

}
