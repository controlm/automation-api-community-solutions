package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.UserFieldFillingHandler;
import com.botscrew.constant.EnvironmentName;
import com.botscrew.constant.Intent;
import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.WordFillingAbstractRequestProcessor;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.EnvironmentService;
import com.botscrew.service.UserService;
import com.botscrew.utils.SDKSimplifierUtill;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.Optional;

@Service
@IntentHandler(intent = Intent.CHOOSE_ENVIRONMENT_INTENT)
@RequiredArgsConstructor
public class ChooseEnvironmentIntent extends WordFillingAbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final UserService userService;
    private final EnvironmentService environmentService;


    //////////////////////State.CHOOSE_ENVIRONMENT
    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> handleJobIntentStart(HandlerInput input, User user) {
        return jobEnvChosen(user, input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> handleJobStatusIntentStart(HandlerInput input, User user) {
        return jobEnvChosen(user, input);
    }

    private Optional<Response> jobEnvChosen(User user, HandlerInput input) {
        Optional<EnvironmentName> environmentName = findEnvironmentName(input);
        return alexaSimpleResponses.getAskResponse(environmentName.map(name -> environmentService.findByUserAndEnvironmentName(user, name)
                .map(env -> {
                    userService.setAndSaveCurrentEnvironment(user, env);
                    userService.changeState(user,State.FILLING_CUSTOM_WORD);
                    return StringUtils.isEmpty(env.getJobName()) ? MessageKey.JOB_NO_DEFAULT_VALUE : MessageKey.JOB_DEFAULT_VALUE_PRESENTS;
                })
                .orElse(MessageKey.NO_ENVIRONMENT_WITH_SUCH_INDEX)).orElse(MessageKey.SORRY_I_DIDNT_GET_THAT), input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fileIntentStart(HandlerInput input, User user) {
        Optional<EnvironmentName> environmentName = findEnvironmentName(input);
        return alexaSimpleResponses.getAskResponse(environmentName.map(name -> environmentService.findByUserAndEnvironmentName(user, name)
                .map(env -> {
                    userService.setAndSaveCurrentEnvironment(user, env);
                    userService.changeState(user,State.FILLING_CUSTOM_WORD);
                    return StringUtils.isEmpty(env.getFileName()) ? MessageKey.FILE_NO_DEFAULT_VALUE : MessageKey.FILE_DEFAULT_VALUE_PRESENTS;
                })
                .orElse(MessageKey.NO_ENVIRONMENT_WITH_SUCH_INDEX)).orElse(MessageKey.SORRY_I_DIDNT_GET_THAT), input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventNameIntentStart(HandlerInput input, User user) {
        return eventDefResp(input, user);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> setEventNameIntentStart(HandlerInput input, User user) {
        return eventDefResp(input, user);
    }

    private Optional<Response> eventDefResp(HandlerInput input, User user) {
        Optional<EnvironmentName> environmentName = findEnvironmentName(input);
        return alexaSimpleResponses.getAskResponse(environmentName.map(name -> environmentService.findByUserAndEnvironmentName(user, name)
                .map(env -> {
                    userService.setAndSaveCurrentEnvironment(user, env);
                    userService.changeState(user,State.FILLING_CUSTOM_WORD);
                    return StringUtils.isEmpty(env.getEventName()) ? MessageKey.EVENT_NO_DEFAULT_VALUE : MessageKey.EVENT_DEFAULT_VALUE_PRESENTS;
                })
                .orElse(MessageKey.NO_ENVIRONMENT_WITH_SUCH_INDEX)).orElse(MessageKey.SORRY_I_DIDNT_GET_THAT), input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fileNameDeployNameIntentStart(HandlerInput input, User user) {
        Optional<EnvironmentName> environmentName = findEnvironmentName(input);
        return alexaSimpleResponses.getAskResponse(environmentName.map(name -> environmentService.findByUserAndEnvironmentName(user, name)
                .map(env -> {
                    userService.setAndSaveCurrentEnvironment(user, env);
                    userService.changeState(user,State.FILLING_CUSTOM_WORD);
                    return StringUtils.isEmpty(env.getFileName()) ? MessageKey.FILE_NO_DEFAULT_VALUE : MessageKey.FILE_DEFAULT_VALUE_PRESENTS;
                })
                .orElse(MessageKey.NO_ENVIRONMENT_WITH_SUCH_INDEX)).orElse(MessageKey.SORRY_I_DIDNT_GET_THAT), input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceIntentStart(HandlerInput input, User user) {
        Optional<EnvironmentName> environmentName = findEnvironmentName(input);
        return alexaSimpleResponses.getAskResponse(environmentName.map(name -> environmentService.findByUserAndEnvironmentName(user, name)
                .map(env -> {
                    userService.setAndSaveCurrentEnvironment(user, env);
                    userService.changeState(user,State.FILLING_CUSTOM_WORD);
                    return StringUtils.isEmpty(env.getResource()) ? MessageKey.RESOURCE_NO_DEFAULT_VALUE : MessageKey.RESOURCE_DEFAULT_VALUE_PRESENTS;
                })
                .orElse(MessageKey.NO_ENVIRONMENT_WITH_SUCH_INDEX)).orElse(MessageKey.SORRY_I_DIDNT_GET_THAT), input);
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


