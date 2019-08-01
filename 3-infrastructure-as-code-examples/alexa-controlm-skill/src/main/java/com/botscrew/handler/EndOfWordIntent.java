package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.StateHandler;
import com.botscrew.annotation.UserFieldFillingHandler;
import com.botscrew.constant.Intent;
import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.processor.AbstractRequestProcessor;
import com.botscrew.processor.WordFillingAbstractRequestProcessor;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Optional;
import java.util.stream.Collectors;

@Service
@IntentHandler(intent = Intent.END_OF_WORD)
@RequiredArgsConstructor
public class EndOfWordIntent extends WordFillingAbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final MessageHolder messageHolder;
    private final UserService userService;

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FOLDER_NAME)
    public Optional<Response> folderResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.FOLDER_VALUE_CONFIRMATION, "$folder_name$", user.getCurrentFolderName());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> jobResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.JOB_VALUE_CONFIRMATION, "$job_name$", user.getCurrentJobName());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> jobStatusResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.JOB_VALUE_CONFIRMATION, "$job_name$", user.getCurrentJobName());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fileResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.FILE_NAME_CONFIRMATION, "$file_name$", user.getCurrentFileName());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fileDeployResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.FILE_NAME_CONFIRMATION, "$file_name$", user.getCurrentFileName());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceDeployResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.RESOURCE_NAME_CONFIRMATION, "$resource_name$", user.getCurrentResource());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventStatusResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.EVENT_NAME_CONFIRMATION, "$event_name$", user.getCurrentEventName());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> setEventResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.EVENT_NAME_CONFIRMATION, "$event_name$", user.getCurrentEventName());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_VALUE)
    public Optional<Response> setEventValueResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.EVENT_VALUE_CONFIRMATION, "$event_value$", user.getCurrentValue());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> setResourceResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.RESOURCE_NAME_CONFIRMATION, "$resource_name$", user.getCurrentResource());
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_VALUE)
    public Optional<Response> setResourceValueResponse(HandlerInput input, User user) {
        return endOfWordResponse(user, input, MessageKey.RESOURCE_VALUE_CONFIRMATION, "$resource_value$", user.getCurrentValue());
    }

    private Optional<Response> endOfWordResponse(User user, HandlerInput input, MessageKey messageKey, String parameterKey, String parameterVal){
        userService.changeState(user, State.END_OF_WORD);
        return alexaSimpleResponses.getAskResponse(messageHolder.getTemplateMessage(messageKey
                , parameterKey
                , parameterVal)
                , input);
    }

    private String getStringSpelledLetterByLetter(String word) {
        return messageHolder.getMessage(MessageKey.SSML_WEAK_BREAK) +
                word.chars()
                        .mapToObj(c -> messageHolder.getTemplateMessage(MessageKey.ONE_CHARACTER_SSML, "$character$", String.valueOf((char) c)))
                        .collect(Collectors.joining());
    }

}

