package com.botscrew.utils;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Intent;
import com.amazon.ask.model.IntentRequest;
import com.amazon.ask.model.Request;
import com.amazon.ask.model.Slot;

import java.util.Map;

public final class SDKSimplifierUtill {

    private SDKSimplifierUtill() {
    }

    public static Map<String, Slot> getSlotsByHandlerInput(HandlerInput input) {
        Request request = input.getRequestEnvelope().getRequest();
        IntentRequest intentRequest = (IntentRequest) request;
        Intent intent = intentRequest.getIntent();
        return intent.getSlots();
    }

}
