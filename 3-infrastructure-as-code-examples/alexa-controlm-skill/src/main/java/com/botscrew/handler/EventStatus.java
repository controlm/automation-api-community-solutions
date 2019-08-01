package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.StateHandler;
import com.botscrew.constant.EnvironmentName;
import com.botscrew.constant.Intent;
import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.AbstractRequestProcessor;
import com.botscrew.service.AlexaDialogResponses;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.EnvironmentService;
import com.botscrew.service.UserService;
import com.botscrew.utils.SDKSimplifierUtill;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.Optional;

@Service
@IntentHandler(intent = Intent.EVENT_STATUS_INTENT)
@RequiredArgsConstructor
public class EventStatus extends AbstractRequestProcessor {

    private final UserService userService;
    private final AlexaSimpleResponses alexaSimpleResponses;
    private final AlexaDialogResponses alexaDialogResponses;
    private final EnvironmentService environmentService;


    @Override
    @StateHandler(states = {State.DEFAULT_STATE})
    public Optional<Response> defaultHandler(HandlerInput input, User user) {
        userService.refreshUserField(user, user::setCurrentEventName);
        user.setUserVariables(UserVariables.EVENT_NAME);
        Optional<EnvironmentName> environmentName = findEnvironmentName(input);
        userService.changeState(user, State.CHOOSE_ENVIRONMENT);
        return environmentName.map(name -> fillJobNameResponse(name, user, input))
                .orElse(alexaDialogResponses.getDialogResponseWithClearSlots(input));
    }


    private Optional<Response> fillJobNameResponse(EnvironmentName name, User user, HandlerInput input) {
        Optional<Environment> environment = environmentService.findByUserAndEnvironmentName(user, name);
        return alexaSimpleResponses.getAskResponse(
                environment
                        .map(env -> {
                            userService.setAndSaveCurrentEnvironment(user, env);
                            userService.changeState(user,State.FILLING_CUSTOM_WORD);
                            return StringUtils.isEmpty(env.getEventName()) ? MessageKey.EVENT_NO_DEFAULT_VALUE : MessageKey.EVENT_DEFAULT_VALUE_PRESENTS;
                        })
                        .orElse(MessageKey.WRONG_ENVIRONMENT_INDEX)
                , input);
    }

    private Optional<EnvironmentName> findEnvironmentName(HandlerInput input) {
        try {
            return Optional.ofNullable(SDKSimplifierUtill.getSlotsByHandlerInput(input).get("environment").getResolutions())
                    .flatMap(resolutions -> EnvironmentName.getEnvironmentNameValue(resolutions.getResolutionsPerAuthority().get(0).getValues().get(0).getValue().getName()));
        }catch (NullPointerException e){
            return Optional.empty();
        }
    }
}
