package com.botscrew.processor;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.dispatcher.request.handler.RequestHandler;
import com.amazon.ask.model.Response;
import com.amazon.ask.request.Predicates;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.StateHandler;
import com.botscrew.constant.PropertyKey;
import com.botscrew.constant.State;
import com.botscrew.entity.User;
import com.botscrew.exception.DuplicateStateException;
import com.botscrew.exception.ProcessorInnerException;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.properties.Property;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationContext;

import javax.annotation.PostConstruct;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public abstract class AbstractRequestProcessor implements RequestHandler {

    @Autowired
    private UserService userService;
    @Autowired
    private AlexaSimpleResponses alexaSimpleResponses;
    @Autowired
    private MessageHolder messageHolder;
    @Autowired
    private Property property;

    private Map<State, Method> handlersByIntent = new ConcurrentHashMap<>();

    @StateHandler(states = {State.DEFAULT_STATE})
    public Optional<Response> defaultHandler(HandlerInput input, User user) {

        return alexaSimpleResponses.getAskResponse(messageHolder.getMessage(MessageKey.SORRY_I_DIDNT_GET_THAT), input);
    }

    @Override
    public boolean canHandle(HandlerInput input) {
        return input.matches(Predicates.intentName(this.getClass().getAnnotation(IntentHandler.class).intent().getValue()));
    }

    @Override
    public Optional<Response> handle(HandlerInput input) {
        if (property.getBooleanPropertyByKey(PropertyKey.ACCOUNT_LINKING_ON)
                && input.getRequestEnvelope().getContext().getSystem().getUser().getAccessToken() == null) {
            return alexaSimpleResponses.getTellResponseWithLinkAccountCard(messageHolder.getMessage(MessageKey.UNLINKED_ACCOUNT), input);
        }

        User user = userService.createUserIfNotExists(input);
        Method instanceMethod = this.findMethod(user.getState());
        try {
            Object object = instanceMethod.invoke(this, Arrays.asList(input, user).toArray());
            return (Optional<Response>) object;
        } catch (InvocationTargetException | IllegalAccessException var5) {
            throw new ProcessorInnerException(var5.getCause());
        }
    }

    @PostConstruct
    public void findHandlers() {
        Arrays.stream(this.getClass().getMethods()).filter(method -> method.isAnnotationPresent(StateHandler.class)).forEach(method -> {
            List<State> states = Arrays.asList(method.getAnnotation(StateHandler.class).states());
            if (states.size() != 0) {
                states.forEach(x -> addAction(x, method));
            } else {
                addAction(State.DEFAULT_STATE, method);
            }
        });
    }

    private State addAction(State state, Method method) {
        if (handlersByIntent.containsKey(state)) {
            throw new DuplicateStateException("Duplication of state processing: state = " + state);
        } else {
            handlersByIntent.put(state, method);
        }
        return state;
    }

    private Method findMethod(State state) {
        Method instanceMethod = this.handlersByIntent.get(state);
        if (instanceMethod == null) instanceMethod = this.handlersByIntent.get(State.DEFAULT_STATE);
        if (instanceMethod == null) throw new IllegalArgumentException("No method with annotation @StateHandler");
        return instanceMethod;
    }


}
