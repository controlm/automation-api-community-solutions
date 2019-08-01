package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.UserFieldFillingHandler;
import com.botscrew.constant.Intent;
import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.WordFillingAbstractRequestProcessor;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.EnvironmentService;
import com.botscrew.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.lang.reflect.Method;
import java.util.Optional;
import java.util.function.Consumer;
import java.util.stream.Collectors;

@Service
@IntentHandler(intent = Intent.CHOOSE_DEFAULT_INTENT)
@RequiredArgsConstructor
public class ChooseDefaultHandler extends WordFillingAbstractRequestProcessor {

    private final MessageHolder messageHolder;
    private final EnvironmentService environmentService;
    private final AlexaSimpleResponses alexaSimpleResponses;
    private final UserService userService;

    //////////////////////State.CHOOSE_ENVIRONMENT
    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> handleJobIntentStart(HandlerInput input, User user) {
        return jobDefaultChosen(user, input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> handleJobStatusIntentStart(HandlerInput input, User user) {
        return jobDefaultChosen(user, input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fileIntentStart(HandlerInput input, User user) {
        return alexaSimpleResponses.getAskResponse(
                environmentService.findUsersDefault(user)
                        .map(env -> {
                            userService.setAndSaveCurrentEnvironment(user, env);
                            userService.changeState(user,State.FILLING_CUSTOM_WORD);
                            return StringUtils.isEmpty(env.getFileName()) ? MessageKey.FILE_NO_DEFAULT_VALUE : MessageKey.FILE_DEFAULT_VALUE_PRESENTS;
                        })
                        .orElse(MessageKey.NO_DEFAULT_ENVIRONMENT)
                , input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventNameIntentStart(HandlerInput input, User user) {
        return eventDefResp(input, user);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> setEventNameIntentStart(HandlerInput input, User user) {
        return eventDefResp(input, user);
    }

    private Optional<Response> eventDefResp(HandlerInput input, User user){
        return alexaSimpleResponses.getAskResponse(
                environmentService.findUsersDefault(user)
                        .map(env -> {
                            userService.setAndSaveCurrentEnvironment(user, env);
                            userService.changeState(user,State.FILLING_CUSTOM_WORD);
                            return StringUtils.isEmpty(env.getEventName()) ? MessageKey.EVENT_NO_DEFAULT_VALUE : MessageKey.EVENT_DEFAULT_VALUE_PRESENTS;
                        })
                        .orElse(MessageKey.NO_DEFAULT_ENVIRONMENT)
                , input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fileNameDeployNameIntentStart(HandlerInput input, User user) {
        return alexaSimpleResponses.getAskResponse(
                environmentService.findUsersDefault(user)
                        .map(env -> {
                            userService.setAndSaveCurrentEnvironment(user, env);
                            userService.changeState(user,State.FILLING_CUSTOM_WORD);
                            return StringUtils.isEmpty(env.getFileName()) ? MessageKey.FILE_NO_DEFAULT_VALUE : MessageKey.FILE_DEFAULT_VALUE_PRESENTS;
                        })
                        .orElse(MessageKey.NO_DEFAULT_ENVIRONMENT)
                , input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceIntentStart(HandlerInput input, User user) {
        return alexaSimpleResponses.getAskResponse(
                environmentService.findUsersDefault(user)
                        .map(env -> {
                            userService.setAndSaveCurrentEnvironment(user, env);
                            userService.changeState(user,State.FILLING_CUSTOM_WORD);
                            return StringUtils.isEmpty(env.getResource()) ? MessageKey.RESOURCE_NO_DEFAULT_VALUE : MessageKey.RESOURCE_DEFAULT_VALUE_PRESENTS;
                        })
                        .orElse(MessageKey.NO_DEFAULT_ENVIRONMENT)
                , input);
    }

    @UserFieldFillingHandler(states = {State.CHOOSE_ENVIRONMENT}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> resourceWithValIntentStart(HandlerInput input, User user) {
        return alexaSimpleResponses.getAskResponse(
                environmentService.findUsersDefault(user)
                        .map(env -> {
                            userService.setAndSaveCurrentEnvironment(user, env);
                            userService.changeState(user,State.FILLING_CUSTOM_WORD);
                            return StringUtils.isEmpty(env.getResource()) ? MessageKey.RESOURCE_NO_DEFAULT_VALUE : MessageKey.RESOURCE_DEFAULT_VALUE_PRESENTS;
                        })
                        .orElse(MessageKey.NO_DEFAULT_ENVIRONMENT)
                , input);
    }

    //////////////////////State.FILLING_CUSTOM_WORD
    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FOLDER_NAME)
    public Optional<Response> folderResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_FOLDER_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getFolderName()
                , MessageKey.FOLDER_VALUE_CONFIRMATION, "$folder_name$", user::setCurrentFolderName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> jobResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_JOB_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getJobName()
                , MessageKey.JOB_VALUE_CONFIRMATION, "$job_name$", user::setCurrentJobName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> jobStatusResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_JOB_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getJobName()
                , MessageKey.JOB_VALUE_CONFIRMATION, "$job_name$", user::setCurrentJobName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fileResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_FILE_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getFileName()
                , MessageKey.FILE_NAME_CONFIRMATION, "file_name$", user::setCurrentFileName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fileDeployResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_FILE_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getFileName()
                , MessageKey.FILE_NAME_CONFIRMATION, "file_name$", user::setCurrentFileName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_RESOURCE_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getResource()
                , MessageKey.RESOURCE_NAME_CONFIRMATION, "$resource_name$", user::setCurrentResource);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_EVENT_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getEventName()
                , MessageKey.EVENT_NAME_CONFIRMATION, "event_name$", user::setCurrentEventName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> setEventResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_EVENT_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getEventName()
                , MessageKey.EVENT_NAME_CONFIRMATION, "$event_name$", user::setCurrentEventName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_VALUE)
    public Optional<Response> setEventValueResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_EVENT_VALUE_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getValue()
                , MessageKey.EVENT_VALUE_RESPONSE, "$event_name$", user::setCurrentValue);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> setResourceResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_RESOURCE_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getResource()
                , MessageKey.RESOURCE_NAME_CONFIRMATION, "$resource_name$", user::setCurrentResource);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_VALUE)
    public Optional<Response> setResourceValueResponse(HandlerInput input, User user) {
        return fillingVariableResponse(user, input, MessageKey.NO_DEFAULT_EVENT_VALUE_ON_CHOOSE
                , environmentService.findUsersCurrentSelected(user).get().getValue()
                , MessageKey.RESOURCE_VALUE_CONFIRMATION, "$resource_value$", user::setCurrentValue);
    }


    ////////////other
    private Optional<Response> jobDefaultChosen(User user, HandlerInput input){
        return alexaSimpleResponses.getAskResponse(
                environmentService.findUsersDefault(user)
                        .map(env -> {
                            userService.setAndSaveCurrentEnvironment(user, env);
                            userService.changeState(user,State.FILLING_CUSTOM_WORD);
                            return StringUtils.isEmpty(env.getJobName()) ? MessageKey.JOB_NO_DEFAULT_VALUE : MessageKey.JOB_DEFAULT_VALUE_PRESENTS;
                        })
                        .orElse(MessageKey.NO_DEFAULT_ENVIRONMENT)
                , input);
    }

    private Optional<Response> fillingVariableResponse(User user, HandlerInput input, MessageKey noDefaultVal, String varName
            , MessageKey folderValueConfirmation, String parameterKey, Consumer<String> currentVarSetter) {
        if (StringUtils.isEmpty(varName)) return alexaSimpleResponses.getAskResponse(noDefaultVal, input);
        currentVarSetter.accept(varName);
        user.setState(State.END_OF_WORD);
        userService.save(user);
        return alexaSimpleResponses.getAskResponse(messageHolder.getTemplateMessage(folderValueConfirmation
                , parameterKey
                , varName)
//                , getStringSpelledLetterByLetter(varName))
                , input);

    }

    private String getStringSpelledLetterByLetter(String word) {
        return messageHolder.getMessage(MessageKey.SSML_WEAK_BREAK) +
                word.chars()
                        .mapToObj(c -> messageHolder.getTemplateMessage(MessageKey.ONE_CHARACTER_SSML, "$character$", String.valueOf((char) c)))
                        .collect(Collectors.joining());
    }
}
