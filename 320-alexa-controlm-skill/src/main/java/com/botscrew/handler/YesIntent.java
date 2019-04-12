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
import com.botscrew.model.bmc.ResourceSetValResult;
import com.botscrew.model.bmc.ResourceStatusResult;
import com.botscrew.model.bmc.RunStatusResult;
import com.botscrew.processor.WordFillingAbstractRequestProcessor;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.BmcApi;
import com.botscrew.service.EnvironmentService;
import com.botscrew.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@IntentHandler(intent = Intent.YES_INTENT)
@RequiredArgsConstructor
public class YesIntent extends WordFillingAbstractRequestProcessor {

    private final String WHITE_SPACE = " ";
    private final UserService userService;
    private final AlexaSimpleResponses alexaSimpleResponses;
    private final BmcApi bmcApi;
    private final EnvironmentService environmentService;
    private final MessageHolder messageHolder;

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.FOLDER_NAME)
    public Optional<Response> folderFilledResponse(HandlerInput input, User user) {
        String response = environmentService.findUsersCurrentSelected(user)
                .map(env -> processRunJobResult(env, user))
                .orElse(messageHolder.getMessage(MessageKey.NO_ENVIRONMENT_ERROR));
        return alexaSimpleResponses.getAskResponse(response, input);
    }

    private String processRunJobResult(Environment env, User user) {
        switch (bmcApi.runJob(env, user.getCurrentJobName(), user.getCurrentFolderName())) {
            case OK:
                return messageHolder.getMessage(MessageKey.JOB_SUCCESSFULLY_STARTED) + WHITE_SPACE + messageHolder.getMessage(MessageKey.END_OF_REQUEST_MESSAGE);
            case WRONG_PASSWORD:
                return messageHolder.getMessage(MessageKey.UNAUTHORISED);
            case WRONG_ENDPOINT:
                return messageHolder.getMessage(MessageKey.WRONG_ENDPOINT);
            case WRONG_DATA:
                return messageHolder.getMessage(MessageKey.RUN_JOB_WRONG_DATA);
            default:
                return messageHolder.getMessage(MessageKey.PROBLEMS_WITH_STARTING_A_JOB);
        }
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> jobFilledResponse(HandlerInput input, User user) {
        userService.refreshUserField(user, user::setCurrentFolderName);
        user.setUserVariables(UserVariables.FOLDER_NAME);
        user.setState(State.FILLING_CUSTOM_WORD);
        userService.save(user);
        return alexaSimpleResponses.getAskResponse(environmentService.findUsersCurrentSelected(user)
                        .map(e -> Optional.ofNullable(e.getFolderName()).isPresent()).orElse(false) ?
                        MessageKey.JOB_FILLED_RESPONSE : MessageKey.FOLDER_NO_DEFAULT_VALUE_PRESENTS
                , input);
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> setEventResponse(HandlerInput input, User user) {
        userService.refreshUserField(user, user::setCurrentValue);
        user.setUserVariables(UserVariables.EVENT_VALUE);
        user.setState(State.FILLING_CUSTOM_WORD);
        userService.save(user);
        return alexaSimpleResponses.getAskResponse(environmentService.findUsersCurrentSelected(user)
                        .map(e -> Optional.ofNullable(e.getValue()).isPresent()).orElse(false) ?
                        MessageKey.SET_EVENT_RESPONSE : MessageKey.SET_EVENT_RESPONSE_NO_DEFAULT_VALUE
                , input);
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.EVENT_VALUE)
    public Optional<Response> setEventValueResponse(HandlerInput input, User user) {
        //TODO api call
        return alexaSimpleResponses.getAskResponse(
                messageHolder.getTemplateMessage(MessageKey.EVENT_VALUE_RESPONSE, "$event_value$", user.getCurrentValue())
                , input);
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> setResourceResponse(HandlerInput input, User user) {
        userService.refreshUserField(user, user::setCurrentValue);
        user.setUserVariables(UserVariables.RESOURCE_VALUE);
        user.setState(State.FILLING_CUSTOM_WORD);
        userService.save(user);
        return alexaSimpleResponses.getAskResponse(MessageKey.SET_RESOURCE_RESPONSE, input);
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.RESOURCE_VALUE)
    public Optional<Response> setResourceValueResponse(HandlerInput input, User user) {
        String response = environmentService.findUsersCurrentSelected(user)
                .map(env -> processResourceSetVal(env, user))
                .orElse(messageHolder.getMessage(MessageKey.NO_ENVIRONMENT_ERROR));
        return alexaSimpleResponses.getAskResponse(response, input);
    }

    private String processResourceSetVal(Environment env, User user) {
        ResourceSetValResult resourceSetValResult = bmcApi.resourceSetVal(env, user.getCurrentResource(), user.getCurrentValue());
        switch (resourceSetValResult.getResult()) {
            case OK:
                return resourceSetValResult.getMessage() + WHITE_SPACE + messageHolder.getMessage(MessageKey.END_OF_REQUEST_MESSAGE);
            case UNAUTHORISED:
                return messageHolder.getMessage(MessageKey.UNAUTHORISED);
            case WRONG_DATA:
                return messageHolder.getMessage(MessageKey.RESOURCE_SET_VAL_WRONG_VAL_NO_INTEGER);
            case BAD_REQUEST:
                return messageHolder.getMessage(MessageKey.RESOURCE_SET_VAL_WRONG_VAL_OUT_OF_BOUNDS);
            case NOT_FOUND:
                return messageHolder.getMessage(MessageKey.RESOURCE_SET_VAL_WRONG_RES_NAME);
            default:
                return messageHolder.getMessage(MessageKey.UNAUTHORISED);
        }
    }

    private String processResourceStatus(Environment env, User user) {
        ResourceStatusResult resourceStatusResult = bmcApi.resourceStatus(env, user.getCurrentResource());
        switch (resourceStatusResult.getResult()) {
            case OK:
                return messageHolder.getTemplateMessage(MessageKey.RESOURCE_STATUS_RESPONSE
                        , "$max$", resourceStatusResult.getResourceStatusResponse().getMax().toString()
                        , "$available$", resourceStatusResult.getResourceStatusResponse().getAvailable())
                        + WHITE_SPACE + messageHolder.getMessage(MessageKey.END_OF_REQUEST_MESSAGE);
            case WRONG_PASSWORD:
                return messageHolder.getMessage(MessageKey.UNAUTHORISED);
            case WRONG_ENDPOINT:
                return messageHolder.getMessage(MessageKey.WRONG_ENDPOINT);
            case WRONG_DATA:
                return messageHolder.getMessage(MessageKey.RESOURCE_STATUS_WRONG_DATA);
            default:
                return messageHolder.getMessage(MessageKey.RESOURCE_STATUS_ERROR);
        }
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> validateFileResponse(HandlerInput input, User user) {
        //TODO api call
        return alexaSimpleResponses.getAskResponse(MessageKey.VALIDATE_FILE_RESPONSE, input);
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> deployFileResponse(HandlerInput input, User user) {
        //TODO api call
        return alexaSimpleResponses.getAskResponse(MessageKey.DEPLOY_FILE_RESPONSE, input);
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> jobStatusResponse(HandlerInput input, User user) {
        String response = environmentService.findUsersCurrentSelected(user)
                .map(env -> processRunStatusResult(env, user))
                .orElse(messageHolder.getMessage(MessageKey.NO_ENVIRONMENT_ERROR));
        return alexaSimpleResponses.getAskResponse(response, input);
    }

    private String processRunStatusResult(Environment env, User user) {
        RunStatusResult runStatusResult = bmcApi.runStatus(env, user.getCurrentJobName());
        switch (runStatusResult.getResult()) {
            case OK:
                return runStatusResult.getRunStatusResponse().getReturned() == 0 ? messageHolder.getMessage(MessageKey.NO_JOB_WHILE_GETTING_STATUS)
                        : messageHolder.getTemplateMessage(MessageKey.JOB_STATUS_RESPONSE, "$job_status$", runStatusResult.getRunStatusResponse().getStatuses().get(0).getStatus())
                        + WHITE_SPACE + messageHolder.getMessage(MessageKey.END_OF_REQUEST_MESSAGE);
            case WRONG_PASSWORD:
                return messageHolder.getMessage(MessageKey.UNAUTHORISED);
            case WRONG_ENDPOINT:
                return messageHolder.getMessage(MessageKey.WRONG_ENDPOINT);
            default:
                return messageHolder.getMessage(MessageKey.PROBLEMS_WITH_JOB_STATUS);
        }
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceStatusResponse(HandlerInput input, User user) {
        String response = environmentService.findUsersCurrentSelected(user)
                .map(env -> processResourceStatus(env, user))
                .orElse(messageHolder.getMessage(MessageKey.NO_ENVIRONMENT_ERROR));
        return alexaSimpleResponses.getAskResponse(response, input);
    }

    @UserFieldFillingHandler(states = {State.END_OF_WORD}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventStatusResponse(HandlerInput input, User user) {
        //TODO api call
        return alexaSimpleResponses.getAskResponse(MessageKey.EVENT_STATUS_RESPONSE, input);
    }
}


