package com.botscrew.messaging.impl;

import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.properties.Property;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@RequiredArgsConstructor
public class MessageHolderImpl implements MessageHolder{

    private final Property property;

    @Override
    public String getMessage(MessageKey key) {
        return property.getStringPropertyByKey(key.getValue());
    }

    @Override
    public String getTemplateMessage(MessageKey key, String parameterKey, String parameterVal) {
        String templateMessage = property.getStringPropertyByKey(key.getValue());
        return templateMessage.replace(parameterKey,parameterVal);
    }

    @Override
    public String getTemplateMessage(MessageKey key, String parameterKey0, String parameterVal0, String parameterKey1, String parameterVal1) {
        String templateMessage = property.getStringPropertyByKey(key.getValue());
        return templateMessage.replace(parameterKey0,parameterVal0).replace(parameterKey1,parameterVal1);
    }

    @Override
    public String getTemplateMessage(MessageKey key, Map<String, String> parameters) {
        String templateMessage = property.getStringPropertyByKey(key.getValue());
        for (Map.Entry<String, String> entry : parameters.entrySet()) {
            templateMessage = templateMessage.replace(entry.getKey(), entry.getValue());
        }
        return templateMessage;
    }
}
