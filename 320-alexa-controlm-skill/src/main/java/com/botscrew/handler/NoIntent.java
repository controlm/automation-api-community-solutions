package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.StateHandler;
import com.botscrew.constant.Intent;
import com.botscrew.constant.State;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.AbstractRequestProcessor;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.BmcApi;
import com.botscrew.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@IntentHandler(intent = Intent.NO_INTENT)
@RequiredArgsConstructor
public class NoIntent extends AbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final UserService userService;

    @StateHandler(states = {State.END_OF_WORD})
    public Optional<Response> handle(HandlerInput input, User user) {
        userService.changeState(user, State.WRONG_WORD_POSITION_QUESTION);
        return alexaSimpleResponses.getAskResponse(MessageKey.WRONG_WORD_POSITION_QUESTION, input);
    }
}


