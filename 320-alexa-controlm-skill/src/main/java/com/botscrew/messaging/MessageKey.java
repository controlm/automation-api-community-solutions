package com.botscrew.messaging;

public enum MessageKey {

    JOB_FILLED_RESPONSE("job.filled.response"),
    WRONG_WORD_SYMBOL_QUESTION("wrong.word.symbol.question"),
    WRONG_WORD_POSITION_QUESTION("wrong.word.position.question"),
    PROBLEMS_WITH_STARTING_A_JOB("problems.with.starting.a.job"),
    NO_DEFAULT_ENVIRONMENT("no.default.environment"),
    JOB_SUCCESSFULLY_STARTED("job.successfully.started"),
    NO_DEFAULT_JOB_ON_CHOOSE("no.default.job.on.choose"),
    NO_DEFAULT_FOLDER_ON_CHOOSE("no.default.folder.on.choose"),

    WRONG_ENDPOINT("wrong.endpoint"),
    FOLDER_NO_DEFAULT_VALUE_PRESENTS("folder.no.default.value.presents"),
    FOLDER_VALUE_CONFIRMATION("folder.value.confirmation"),
    LETTER_NOT_RECOGNISED("letter.not.recognised"),
    MAIL_SUBJECT("mail.subject"),
    JOB_DEFAULT_VALUE_PRESENTS("job.default.value.presents"),
    JOB_NO_DEFAULT_VALUE("job.no.default.value"),
    WRONG_ENVIRONMENT_INDEX("wrong.environment.index"),
    DEFINE_ENVIRONMENT_INTENT_RESPONSE("define.environment.intent.response"),
    UNLINKED_ACCOUNT("unlinked.account"),
    END_OF_WORD("end.of.word"),
    OK_YOUR_SESSION_HAS_BEEN_CANCELLED("session.cancelled"),
    SORRY_I_DIDNT_GET_THAT("fallback.response"),
    FIRST_TIME_USER_LAUNCH_TEXT("first.time.user.launch.text"),
    LAUNCH_TEXT("launch.response"),
    BYE("farewell.response"),
    OK_GOOD_BYE("session.ended.response"),
    DEPLOY_INTENT_ANSWER("deploy.intent.answer"),
    LETTER_INTENT_ANSWER("letter.intent.answer"),
    MAIL("mail.message"),
    JOB_VALUE_CONFIRMATION("job.value.confirmation"),

    SSML_WEAK_BREAK("ssml.weak.break"),
    ONE_CHARACTER_SSML("ssml.one.character"),
    JOB_STATUS_RESPONSE("job.status.response"),
    FILE_NO_DEFAULT_VALUE("file.no.default.value"),
    FILE_DEFAULT_VALUE_PRESENTS("file.default.value.presents"),
    VALIDATE_FILE_RESPONSE("validate.file.response"),
    FILE_NAME_CONFIRMATION("file.name.confirmation"),
    NO_DEFAULT_FILE_ON_CHOOSE("no.default.file.on.choose"),
    DEPLOY_FILE_RESPONSE("deploy.file.response"),
    RESOURCE_NO_DEFAULT_VALUE("resource.no.default.value"),
    RESOURCE_DEFAULT_VALUE_PRESENTS("resource.default.value.presents"),
    RESOURCE_STATUS_RESPONSE("resource.status.response"),
    RESOURCE_NAME_CONFIRMATION("resource.name.confirmation"),
    NO_DEFAULT_RESOURCE_ON_CHOOSE("no.default.resource.on.choose"),
    EVENT_NO_DEFAULT_VALUE("event.no.default.value"),
    EVENT_DEFAULT_VALUE_PRESENTS("event.default.value.presents"),
    EVENT_STATUS_RESPONSE("event.status.response"),
    EVENT_NAME_CONFIRMATION("event.name.confirmation"),
    NO_DEFAULT_EVENT_ON_CHOOSE("no.default.event.on.choose"),
    NO_DEFAULT_EVENT_VALUE_ON_CHOOSE("no.default.event.value.on.choose"),
    SET_EVENT_RESPONSE("set.event.response"),
    SET_EVENT_RESPONSE_NO_DEFAULT_VALUE("set.event.response.no.default.value"),
    EVENT_VALUE_RESPONSE("event.value.response"),
    EVENT_VALUE_CONFIRMATION("event.value.confirmation"),
    RESOURCE_VALUE_CONFIRMATION("resource.value.confirmation"),
    SET_RESOURCE_RESPONSE("set.resource.response"),
    SET_RESOURCE_RESPONSE_NO_DEFAULT_VALUE("set.resource.response.no.default.value"),
    RESOURCE_VALUE_RESPONSE("resource.value.response"),
    DEFAULT_ENVIRONMENT_SET_SUCCESSFULLY("default.environment.set.successfully"),
    DEFAULT_ENVIRONMENT_SET_UNSUCCESSFULLY("default.environment.set.unsuccessfully"),
    HELP_RESPONSE("help.response"),
    NO_ENVIRONMENT_WITH_SUCH_INDEX("no.environment.with.such.index"),
    NO_ENVIRONMENT_ERROR("no.environment.error"),
    RUN_JOB_WRONG_DATA("run.job.wrong.data"),

    UNAUTHORISED("unauthorised.exception"),
    PROBLEMS_WITH_JOB_STATUS("problems.with.job.status"),
    NO_JOB_WHILE_GETTING_STATUS("no.job.while.getting.status"),
    RESOURCE_STATUS_WRONG_DATA("resource.status.wrong.data"),
    RESOURCE_STATUS_ERROR("resource.status.error"),
    RESOURCE_SET_VAL_WRONG_RES_NAME("resource.set.val.wrong.res.name"),
    RESOURCE_SET_VAL_WRONG_VAL_NO_INTEGER("resource.set.val.wrong.val.no.integer"),
    RESOURCE_SET_VAL_WRONG_VAL_OUT_OF_BOUNDS("resource.set.val.wrong.val.out.of.bounds"),
    END_OF_REQUEST_MESSAGE("end.of.request.message");

    private String value;

    MessageKey(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
