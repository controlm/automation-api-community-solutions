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
import com.botscrew.utils.SDKSimplifierUtill;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Optional;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.stream.Collectors;

@Service
@IntentHandler(intent = Intent.LETTER_INTENT)
@RequiredArgsConstructor
public class LetterIntent extends WordFillingAbstractRequestProcessor {

    private final UserService userService;
    private final AlexaSimpleResponses alexaSimpleResponses;
    private final MessageHolder messageHolder;


    ////////////////////////FILLING_CUSTOM_WORD
    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> runJobHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FOLDER_NAME)
    public Optional<Response> folderNameHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFolderName, user::setCurrentFolderName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> jobStatusHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fileHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fileDeployHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> eventWithValHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.EVENT_VALUE)
    public Optional<Response> eventValueHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> resourceWithValHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource);
    }

    @UserFieldFillingHandler(states = {State.FILLING_CUSTOM_WORD}, userVariable = UserVariables.RESOURCE_VALUE)
    public Optional<Response> resourceValueHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue);
    }

    ////////////////////////WRONG_WORD_SYMBOL_QUESTION
    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.JOB_NAME)
    public Optional<Response> runJobWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.FOLDER_NAME)
    public Optional<Response> folderNameWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFolderName, user::setCurrentFolderName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.JOB_STATUS_NAME)
    public Optional<Response> jobStatusWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentJobName, user::setCurrentJobName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.FILE_NAME)
    public Optional<Response> fileWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.FILE_NAME_DEPLOY)
    public Optional<Response> fileDeployWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentFileName, user::setCurrentFileName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.RESOURCE)
    public Optional<Response> resourceWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.EVENT_NAME)
    public Optional<Response> eventWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.EVENT_WITH_VAL_NAME)
    public Optional<Response> eventWithValWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentEventName, user::setCurrentEventName, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.EVENT_VALUE)
    public Optional<Response> eventValWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.RESOURCE_WITH_VAL)
    public Optional<Response> resourceWithValWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentResource, user::setCurrentResource, user.getWrongWordPosition());
    }

    @UserFieldFillingHandler(states = {State.WRONG_WORD_SYMBOL_QUESTION}, userVariable = UserVariables.RESOURCE_VALUE)
    public Optional<Response> resourceValWrongSymbolHandler(HandlerInput input, User user){
        return recogniseLetterAndAddToWord(input, user, user::getCurrentValue, user::setCurrentValue, user.getWrongWordPosition());
    }



    ///////////////other
    private Optional<Response> recogniseLetterAndAddToWord(HandlerInput input, User user, Supplier<String> wordGetter, Consumer<String> wordSetter) {
        return recogniseLetterAndAddToWord(input, user, wordGetter, wordSetter, wordGetter.get().length());
    }

    private Optional<Response> recogniseLetterAndAddToWord(HandlerInput input, User user, Supplier<String> wordGetter, Consumer<String> wordSetter, int position) {
        Optional<String> caseOpt = Optional.ofNullable(SDKSimplifierUtill.getSlotsByHandlerInput(input).get("case").getValue());
        Optional<String> letter = findLetter(input);
        return letter
                .map(l -> {
                    wordSetter.accept(caseOpt.isPresent() && caseOpt.get().equals("upper") ?
                            placeStringInPosition(wordGetter.get(), l.toUpperCase(), position) :
                            placeStringInPosition(wordGetter.get(), l.toLowerCase(), position));
                    user.setState(State.FILLING_CUSTOM_WORD);
                    userService.save(user);
                    return alexaSimpleResponses.getAskResponse(messageHolder.getMessage(MessageKey.LETTER_INTENT_ANSWER), input);
                })
                .orElse(alexaSimpleResponses.getAskResponse(messageHolder.getMessage(MessageKey.LETTER_NOT_RECOGNISED), input));

    }

    private Optional<String> findLetter(HandlerInput input) {
        try {
            return Optional.ofNullable(SDKSimplifierUtill.getSlotsByHandlerInput(input).get("letter").getResolutions().getResolutionsPerAuthority().get(0).getValues().get(0).getValue().getName());
        }catch (Exception e){
            return Optional.empty();
        }
    }

    private String placeStringInPosition(String word, String symbol, int position) {
        if (position == word.length()) return word + symbol;
        if (position == 0) return symbol + (word.length() == 0 ? "" : word.substring(1));
        if (position == word.length() - 1) return word.substring(0, position) + symbol;
        return word.substring(0, position)+ symbol +word.substring(position+1);
    }

    private String getStringSpelledLetterByLetter(String word) {
        return messageHolder.getMessage(MessageKey.SSML_WEAK_BREAK) +
                word.chars()
                        .mapToObj(c -> messageHolder.getTemplateMessage(MessageKey.ONE_CHARACTER_SSML, "$character$", String.valueOf((char) c)))
                        .collect(Collectors.joining());
    }
}


