package com.botscrew.service.impl;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Intent;
import com.amazon.ask.model.IntentRequest;
import com.amazon.ask.model.Response;
import com.amazon.ask.model.Slot;
import com.botscrew.service.AlexaDialogResponses;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.Optional;

@Service
public class AlexaDialogResponsesImpl implements AlexaDialogResponses {

    @Override
    public Optional<Response> getDialogResponse(HandlerInput handlerInput) {
        return handlerInput.getResponseBuilder()
                .addDelegateDirective(getIntent(handlerInput))
                .build();
    }

    @Override
    public Optional<Response> getDialogResponseWithClearSlots(HandlerInput handlerInput) {
        return handlerInput.getResponseBuilder()
                .addDelegateDirective(getIntentWithClearSlots(handlerInput))
                .build();
    }

    private Intent getIntentWithClearSlots(HandlerInput handlerInput) {
        Intent intent = ((IntentRequest) handlerInput.getRequestEnvelope().getRequest()).getIntent();
        intent.getSlots().forEach((s, slot) -> intent.getSlots().put(s, Slot.builder().withName(slot.getName()).withConfirmationStatus(slot.getConfirmationStatus()).build()));
        return intent;
    }

    private Intent getIntent(HandlerInput handlerInput) {
        return ((IntentRequest) handlerInput.getRequestEnvelope().getRequest()).getIntent();
    }

}