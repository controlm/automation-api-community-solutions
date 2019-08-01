package com.botscrew.service;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.botscrew.constant.State;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;

import java.util.Optional;
import java.util.function.Consumer;

public interface UserService {

    void refreshUserField(User user, Consumer<String> setter);

    void setAndSaveCurrentEnvironment(User user, Environment environment);

    void setAndSaveDefaultEnvironment(User user, Environment environment);

    User createUserIfNotExists(HandlerInput input);

    void changeState(User user, State state);

    Optional<User> findById(Long id);

    User save(User user);
}
