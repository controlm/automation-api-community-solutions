package com.botscrew.messaging;

import java.util.Map;

public interface MessageHolder {

    String getMessage(MessageKey key);

    String getTemplateMessage(MessageKey key, String parameterKey, String parameterVal);

    String getTemplateMessage(MessageKey key, String parameterKey0, String parameterVal0, String parameterKey1, String parameterVal1);

    String getTemplateMessage(MessageKey key, Map<String, String> parameters);
}
