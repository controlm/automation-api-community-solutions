package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.LaunchRequest;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.StateHandler;
import com.botscrew.constant.State;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.AbstractRequestProcessor;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.MailService;
import com.botscrew.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Optional;

import static com.amazon.ask.request.Predicates.requestType;

@Service
@RequiredArgsConstructor
public class LaunchRequestHandler extends AbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final MessageHolder messageHolder;
    private final UserService userService;
    private final MailService mailService;

    @Override
    public boolean canHandle(HandlerInput input) {
        return input.matches(requestType(LaunchRequest.class));
    }

    @Override
    @StateHandler(states = {State.DEFAULT_STATE})
    public Optional<Response> defaultHandler(HandlerInput input, User user) {
        userService.changeState(user, State.ON_LAUNCH);
        if (user.getFirstTimeUser()) {
            user.setFirstTimeUser(false);
            userService.save(user);
            mailService.sendMailWithEnvironments(user);
            return alexaSimpleResponses.getAskResponse(messageHolder.getMessage(MessageKey.FIRST_TIME_USER_LAUNCH_TEXT), input);
        } else {
            return alexaSimpleResponses.getAskResponse(messageHolder.getMessage(MessageKey.LAUNCH_TEXT), input);
        }

    }
}