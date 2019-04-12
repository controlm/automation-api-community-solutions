package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.StateHandler;
import com.botscrew.constant.Intent;
import com.botscrew.constant.State;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.AbstractRequestProcessor;
import com.botscrew.service.AlexaSimpleResponses;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@IntentHandler(intent = Intent.STOP_INTENT)
@RequiredArgsConstructor
public class StopRequestHandler extends AbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final MessageHolder messageHolder;


    @Override
    @StateHandler(states = {State.DEFAULT_STATE})
    public Optional<Response> defaultHandler(HandlerInput input, User user) {
        return alexaSimpleResponses.getTellResponse(messageHolder.getMessage(MessageKey.OK_GOOD_BYE), input);
    }
}
