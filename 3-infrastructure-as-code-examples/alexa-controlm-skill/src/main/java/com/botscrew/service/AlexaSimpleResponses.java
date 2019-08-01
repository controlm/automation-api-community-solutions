package com.botscrew.service;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.messaging.MessageKey;

import java.util.Optional;

public interface AlexaSimpleResponses {

    Optional<Response> getAskResponse(String text, HandlerInput input);

    Optional<Response> getAskResponseWithCard(String text, String cardText, HandlerInput input);

    Optional<Response> getAskResponse(MessageKey key, HandlerInput input);

    Optional<Response> getAskResponseWithCard(MessageKey key, MessageKey cardTextKey, HandlerInput input);

    Optional<Response> getAskResponse(MessageKey key, MessageKey repromptKey, HandlerInput input);

    Optional<Response> getAskResponseWithCard(MessageKey key, MessageKey repromptKey, MessageKey cardTextKey, HandlerInput input);

    Optional<Response> getAskResponse(String text, String reprompt, HandlerInput input);

    Optional<Response> getAskResponseWithCard(String text, String reprompt, String cardText, HandlerInput input);

    Optional<Response> getTellResponse(MessageKey key, HandlerInput input);

    Optional<Response> getTellResponseWithCard(MessageKey key, MessageKey cardTextKey, HandlerInput input);

    Optional<Response> getTellResponse(String text, HandlerInput input);

    Optional<Response> getTellResponseWithLinkAccountCard(String text, HandlerInput input);

    Optional<Response> getTellResponseWithCard(String text, String cardText, HandlerInput input);
}
