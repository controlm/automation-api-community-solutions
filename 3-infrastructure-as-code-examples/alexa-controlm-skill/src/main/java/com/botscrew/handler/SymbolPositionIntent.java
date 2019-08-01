package com.botscrew.handler;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.model.Response;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.UserFieldFillingHandler;
import com.botscrew.constant.EnvironmentName;
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
import com.botscrew.utils.SDKSimplifierUtill;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.Optional;
import java.util.function.Consumer;
import java.util.function.Supplier;

@Service
@IntentHandler(intent = Intent.SYMBOL_POSITION)
@RequiredArgsConstructor
public class SymbolPositionIntent extends WordFillingAbstractRequestProcessor {

    private final AlexaSimpleResponses alexaSimpleResponses;
    private final UserService userService;
    private final EnvironmentService environmentService;
    private final MessageHolder messageHolder;

    @UserFieldFillingHandler(states = {State.WRONG_WORD_POSITION_QUESTION})
    public Optional<Response> wrongWordPositionQuestionHandler(HandlerInput input, User user) {
        Optional<Integer> position = findSlotId(input, "position");
        return position
                .map(p -> {
                    user.setState(State.WRONG_WORD_SYMBOL_QUESTION);
                    user.setWrongWordPosition(p - 1);
                    userService.save(user);
                    return alexaSimpleResponses.getAskResponse(MessageKey.WRONG_WORD_SYMBOL_QUESTION, input);
                })
                .orElse(alexaSimpleResponses.getAskResponse(MessageKey.SORRY_I_DIDNT_GET_THAT, input));
    }

    private Optional<Integer> findSlotId(HandlerInput input, String slotName) {
        try {
            return Optional.ofNullable(Integer.valueOf(SDKSimplifierUtill.getSlotsByHandlerInput(input).get(slotName).getResolutions().getResolutionsPerAuthority().get(0).getValues().get(0).getValue().getId()));
        } catch (NullPointerException e) {
            return Optional.empty();
        }
    }



    ////////////////////////FILLING_CUSTOM_WORD
    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> fillingWordJobIntent(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FOLDER_NAME)
    public Optional<Response> fillingWordFolderIntent(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFolderName, user::setCurrentFolderName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> fillingWordJobStatusIntent(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fillingWordFileNameIntent(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fillingWordFileDeployNameIntent(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> fillingWordFileResourceStatus(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> fillingWordEvent(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> fillingWordSetEvent(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_VALUE)
    public Optional<Response> fillingWordEventValue(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> fillingWordSetResource(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_VALUE)
    public Optional<Response> fillingWordResourceValue(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue);
    }

    ////////////////////////WRONG_WORD_SYMBOL_QUESTION
    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> jobWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.FOLDER_NAME)
    public Optional<Response> folderWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFolderName, user::setCurrentFolderName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> jobStatusWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fileWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fileDeployWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceStatusWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> setEventWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.EVENT_VALUE)
    public Optional<Response> setEventValueWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> setResourceWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.RESOURCE_VALUE)
    public Optional<Response> setResourceValueWrongWordSymbolQuestion(HandlerInput input, User user) {
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue, user.getWrongWordPosition());
    }



    ////////////other
    private Optional<Response> recogniseLetterAndAddToWord(HandlerInput input, User user, Supplier<String> wordGetter, Consumer<String> wordSetter, int position) {
        Optional<String> symbol = findSlotVal(input, "position");
        return symbol.map(s -> {
            wordSetter.accept(placeStringInPosition(wordGetter.get(), s, position));
            user.setState(State.FILLING_CUSTOM_WORD);
            userService.save(user);
            return alexaSimpleResponses.getAskResponse(messageHolder.getMessage(MessageKey.LETTER_INTENT_ANSWER), input);
        })
                .orElse(alexaSimpleResponses.getAskResponse(messageHolder.getMessage(MessageKey.LETTER_NOT_RECOGNISED), input));
    }

    private Optional<Response> recogniseLetterAndAddToWord(HandlerInput input, User user, Supplier<String> wordGetter, Consumer<String> wordSetter) {
        return recogniseLetterAndAddToWord(input, user, wordGetter, wordSetter, wordGetter.get().length());
    }

    private Optional<String> findSlotVal(HandlerInput input, String slot) {
        try {
            String s = SDKSimplifierUtill.getSlotsByHandlerInput(input).get(slot).getResolutions().getResolutionsPerAuthority().get(0).getValues().get(0).getValue().getId();
            return Optional.ofNullable(s);
        } catch (NullPointerException e) {
            return Optional.empty();
        }
    }

    private String placeStringInPosition(String word, String symbol, int position) {
        if (position == word.length()) return word + symbol;
        if (position == 0) return symbol + (word.length() == 0 ? "" : word.substring(1));
        if (position == word.length() - 1) return word.substring(0, position) + symbol;
        return word.substring(0, position) + symbol + word.substring(position + 1);
    }
}


