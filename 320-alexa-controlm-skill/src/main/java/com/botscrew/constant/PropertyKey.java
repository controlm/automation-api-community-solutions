package com.botscrew.constant;

public enum PropertyKey {

    BASE_URL("base.url"),

    SKILL_NAME("skill.name"),
    SKILL_ID("skill.id"),
    ACCOUNT_LINKING_ON("alexa.account.linking.on"),
    AMAZON_PROFILE_INFO_URL("amazon.profile.info.url"),

    MAIL_SMTP_GMAIL_COM("mail.smtp.gmail.com"),
    MAIL_PORT("mail.port"),
    MAIL_FROM("mail.from"),
    MAIL_PASSWORD("mail.password"),
    MAIL_TRANSPORT_PROTOCOL("mail.transport.protocol"),
    MAIL_SMTP_STARTTLS_ENABLE("mail.smtp.starttls.enable"),

    BMC_LOGIN("endpoint.login"),
    BMC_JOB_RUN("endpoint.job.run"),
    BMC_LOGOUT("endpoint.logout"),
    BMC_RUN_STATUS("endpoint.run.status"),
    BMC_RESOURCE_STATUS("endpoint.resource.status"),
    BMC_RESOURCE_SET_VALUE("endpoint.resource.set.value");

    private String value;

    PropertyKey(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
