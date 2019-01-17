package com.botscrew.service.impl;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.constant.PropertyKey;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.properties.Property;
import com.botscrew.service.AlexaSimpleResponses;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AlexaSimpleResponsesImpl implements AlexaSimpleResponses {

    private final Property property;
    private final MessageHolder messageHolder;


    @Override
    public Optional<Response> getAskResponse(String text, HandlerInput input) {
        return getAskResponse(text, text, input);
    }

    @Override
    public Optional<Response> getAskResponseWithCard(String text, String cardText, HandlerInput input) {
        return getAskResponseWithCard(text, text, cardText, input);
    }

    @Override
    public Optional<Response> getAskResponse(MessageKey key, HandlerInput input) {
        return getAskResponse(messageHolder.getMessage(key), input);
    }

    @Override
    public Optional<Response> getAskResponseWithCard(MessageKey key, MessageKey cardTextKey, HandlerInput input) {
        return getAskResponseWithCard(messageHolder.getMessage(key), messageHolder.getMessage(cardTextKey), input);
    }

    @Override
    public Optional<Response> getAskResponse(MessageKey key, MessageKey repromptKey, HandlerInput input) {
        return getAskResponse(messageHolder.getMessage(key), messageHolder.getMessage(repromptKey), input);
    }

    @Override
    public Optional<Response> getAskResponseWithCard(MessageKey key, MessageKey repromptKey, MessageKey cardTextKey, HandlerInput input) {
        return getAskResponseWithCard(messageHolder.getMessage(key), messageHolder.getMessage(repromptKey), messageHolder.getMessage(cardTextKey), input);
    }

    @Override
    public Optional<Response> getAskResponse(String text, String reprompt, HandlerInput input) {
        return getAskResponseWithCard(text, reprompt, text, input);
    }

    @Override
    public Optional<Response> getAskResponseWithCard(String text, String reprompt, String cardText, HandlerInput input) {
        return input.getResponseBuilder()
                .withSpeech(text)
                .withSimpleCard(property.getStringPropertyByKey(PropertyKey.SKILL_NAME), cardText)
                .withReprompt(reprompt)
                .build();
    }

    @Override
    public Optional<Response> getTellResponse(MessageKey key, HandlerInput input) {
        return getTellResponse(messageHolder.getMessage(key), input);
    }

    @Override
    public Optional<Response> getTellResponseWithCard(MessageKey key, MessageKey cardTextKey, HandlerInput input) {
        return getTellResponseWithCard(messageHolder.getMessage(key), messageHolder.getMessage(cardTextKey), input);
    }

    @Override
    public Optional<Response> getTellResponse(String text, HandlerInput input) {
        return getTellResponseWithCard(text, text, input);
    }


    @Override
    public Optional<Response> getTellResponseWithLinkAccountCard(String text, HandlerInput input) {
        return input.getResponseBuilder()
                .withLinkAccountCard()
                .withSpeech(text)
                .build();
    }

    @Override
    public Optional<Response> getTellResponseWithCard(String text, String cardText, HandlerInput input) {
        return input.getResponseBuilder()
                .withSpeech(text)
                .withSimpleCard(property.getStringPropertyByKey(PropertyKey.SKILL_NAME), cardText)
                .build();
    }

}
