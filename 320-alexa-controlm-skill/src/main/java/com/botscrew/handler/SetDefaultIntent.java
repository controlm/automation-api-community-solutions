package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.StateHandler;
import com.botscrew.constant.EnvironmentName;
import com.botscrew.constant.Intent;
import com.botscrew.constant.State;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.AbstractRequestProcessor;
import com.botscrew.service.AlexaDialogResponses;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.EnvironmentService;
import com.botscrew.service.UserService;
import com.botscrew.utils.SDKSimplifierUtill;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@IntentHandler(intent = Intent.DEFAULT_ENVIRONMENT_INTENT)
@RequiredArgsConstructor
public class SetDefaultIntent extends AbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final AlexaDialogResponses alexaDialogResponses;
    private final UserService userService;
    private final EnvironmentService environmentService;

    @Override
    @StateHandler(states = {State.DEFAULT_STATE})
    public Optional<Response> defaultHandler(HandlerInput input, User user) {
        userService.changeState(user, State.CHOOSE_ENVIRONMENT);
        Optional<EnvironmentName> environmentName = findEnvironmentName(input);
        return environmentName.map(name -> setDefaultEnv(name, user, input))
                .orElse(alexaDialogResponses.getDialogResponseWithClearSlots(input));
    }

    private Optional<Response> setDefaultEnv(EnvironmentName environmentName, User user, HandlerInput input) {
        return environmentService.findByUserAndEnvironmentName(user, environmentName)
                .map(environment -> {
                    userService.setAndSaveDefaultEnvironment(user, environment);
                    return alexaSimpleResponses.getAskResponse(MessageKey.DEFAULT_ENVIRONMENT_SET_SUCCESSFULLY, input);
                })
                .orElse(alexaSimpleResponses.getAskResponse(MessageKey.DEFAULT_ENVIRONMENT_SET_UNSUCCESSFULLY, input));
    }

    private Optional<EnvironmentName> findEnvironmentName(HandlerInput input) {
        try {
            return Optional.ofNullable(SDKSimplifierUtill.getSlotsByHandlerInput(input).get("environment").getResolutions())
                    .flatMap(resolutions -> EnvironmentName.getEnvironmentNameValue(resolutions.getResolutionsPerAuthority().get(0).getValues().get(0).getValue().getName()));
        } catch (NullPointerException e) {
            return Optional.empty();
        }
    }
}
