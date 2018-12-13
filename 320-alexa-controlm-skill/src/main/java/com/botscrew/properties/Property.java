package com.botscrew.properties;


import com.botscrew.constant.PropertyKey;
import lombok.RequiredArgsConstructor;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.io.File;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Component
@RequiredArgsConstructor
public class Property {
    private final Environment environment;

    public String getStringPropertyByKey(final PropertyKey propertyKey) {
        return environment.getProperty(propertyKey.getValue());
    }

    public String getStringPropertyByKey(final PropertyKey propertyKey, Map<String, String> parameters) {
        String property = environment.getProperty(propertyKey.getValue());
        for (Map.Entry<String, String> entry : parameters.entrySet()) {
            property = property.replace(entry.getKey(), entry.getValue());
        }
        return property;
    }

    public String getStringPropertyByKey(final PropertyKey propertyKey, String key, String val) {
        String property = environment.getProperty(propertyKey.getValue());
        property = property.replace(key, val);
        return property;
    }

    public String getStringPropertyByKey(final String propertyKey) {
        return environment.getProperty(propertyKey);
    }

    public Integer getIntegerPropertyByKey(final PropertyKey propertyKey) {
        return Integer.valueOf(environment.getProperty(propertyKey.getValue()));
    }

    public Integer getIntegerPropertyByKey(final String propertyKey) {
        return Integer.valueOf(environment.getProperty(propertyKey));
    }

    public Boolean getBooleanPropertyByKey(final PropertyKey key) {
        return Boolean.valueOf(environment.getProperty(key.getValue()));
    }

    public Boolean getBooleanPropertyByKey(final String key) {
        return Boolean.valueOf(environment.getProperty(key));
    }

    public List<String> getListOfStringPropertyByKey(final PropertyKey key, final String spliterator) {
        return Arrays.stream(environment.getProperty(key.getValue()).split(spliterator)).collect(Collectors.toList());
    }

    public List<String> getListOfStringPropertyByKey(final String key, final String spliterator) {
        return Arrays.stream(environment.getProperty(key).split(spliterator)).collect(Collectors.toList());
    }

    public File getFileFromPropertyPath(final PropertyKey key) {
        return new File(environment.getProperty(key.getValue()));
    }

    public File getFileFromPropertyPath(final String key) {
        return new File(environment.getProperty(key));
    }
}
