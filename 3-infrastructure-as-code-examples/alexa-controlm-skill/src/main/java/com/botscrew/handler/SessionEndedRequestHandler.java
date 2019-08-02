package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.amazon.ask.model.SessionEndedRequest;
import com.botscrew.annotation.StateHandler;
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

import static com.amazon.ask.request.Predicates.requestType;

@Service
@RequiredArgsConstructor
public class SessionEndedRequestHandler extends AbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final MessageHolder messageHolder;

    @Override
    public boolean canHandle(HandlerInput input) {
        return input.matches(requestType(SessionEndedRequest.class));
    }

    @Override
    @StateHandler(states = {State.DEFAULT_STATE})
    public Optional<Response> defaultHandler(HandlerInput input, User user) {
        return alexaSimpleResponses.getTellResponse(messageHolder.getMessage(MessageKey.BYE), input);
    }

}
