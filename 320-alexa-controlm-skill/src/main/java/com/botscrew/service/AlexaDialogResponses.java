package com.botscrew.service;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;

import java.util.Optional;

public interface AlexaDialogResponses {

    Optional<Response> getDialogResponse(HandlerInput handlerInput);

    Optional<Response> getDialogResponseWithClearSlots(HandlerInput handlerInput);
}
