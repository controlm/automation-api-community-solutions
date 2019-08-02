package com.botscrew.processor;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.amazon.ask.dispatcher.request.handler.RequestHandler;
import com.amazon.ask.model.Response;
import com.amazon.ask.request.Predicates;
import com.botscrew.annotation.DefaultHandler;
import com.botscrew.annotation.IntentHandler;
import com.botscrew.annotation.StateHandler;
import com.botscrew.annotation.UserFieldFillingHandler;
import com.botscrew.constant.PropertyKey;
import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;
import com.botscrew.entity.User;
import com.botscrew.exception.DuplicateStateException;
import com.botscrew.exception.ProcessorInnerException;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.properties.Property;
import com.botscrew.service.AlexaSimpleResponses;
import com.botscrew.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;

import javax.annotation.PostConstruct;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public abstract class WordFillingAbstractRequestProcessor extends AbstractRequestProcessor {

    @Autowired
    private UserService userService;
    @Autowired
    private AlexaSimpleResponses alexaSimpleResponses;
    @Autowired
    private MessageHolder messageHolder;
    @Autowired
    private Property property;

    private Method defaultHandler;

    private Map<StateUserVariable, Method> handlersByIntent = new ConcurrentHashMap<>();

    @DefaultHandler
    public Optional<Response> defaultHandler(HandlerInput input, User user) {
        return alexaSimpleResponses.getAskResponse(MessageKey.SORRY_I_DIDNT_GET_THAT, input);
    }

    @Override
    public Optional<Response> handle(HandlerInput input) {
        if (property.getBooleanPropertyByKey(PropertyKey.ACCOUNT_LINKING_ON)
                && input.getRequestEnvelope().getContext().getSystem().getUser().getAccessToken() == null) {
            return alexaSimpleResponses.getTellResponseWithLinkAccountCard(messageHolder.getMessage(MessageKey.UNLINKED_ACCOUNT), input);
        }

        User user = userService.createUserIfNotExists(input);
        Method instanceMethod = this.findMethod(new StateUserVariable(user.getState(), user.getUserVariables()));
        try {
            Object object = instanceMethod.invoke(this, Arrays.asList(input, user).toArray());
            return (Optional<Response>) object;
        } catch (InvocationTargetException | IllegalAccessException var5) {
            throw new ProcessorInnerException(var5.getCause());
        }
    }

    @PostConstruct
    public void findHandlers() {
        Arrays.stream(this.getClass().getMethods()).filter(method -> method.isAnnotationPresent(UserFieldFillingHandler.class)).forEach(method -> {
            List<State> states = Arrays.asList(method.getAnnotation(UserFieldFillingHandler.class).states());
            if (states.size() != 0) {
                states.forEach(x -> addAction(x, method.getAnnotation(UserFieldFillingHandler.class).userVariable(),method));
            } else {
                addAction(State.DEFAULT_STATE, method.getAnnotation(UserFieldFillingHandler.class).userVariable(), method);
            }
        });
        Arrays.stream(this.getClass().getMethods()).filter(method -> method.isAnnotationPresent(DefaultHandler.class)).forEach(
                method -> defaultHandler = method
        );
    }

    private State addAction(State state, UserVariables userVariables, Method method) {
        if (handlersByIntent.containsKey(state)) {
            throw new DuplicateStateException("Duplication of state processing: state = " + state);
        } else {
            handlersByIntent.put(new StateUserVariable(state, userVariables), method);
        }
        return state;
    }

    private Method findMethod(StateUserVariable stateUserVariable) {
        Method instanceMethod = this.handlersByIntent.get(stateUserVariable);
        if (instanceMethod == null) instanceMethod = this.handlersByIntent.get(new StateUserVariable(State.DEFAULT_STATE,stateUserVariable.getUserVariables()));
        if (instanceMethod == null) instanceMethod = this.handlersByIntent.get(new StateUserVariable(stateUserVariable.getState(),UserVariables.DEFAULT_VALUE));
        if (instanceMethod == null) instanceMethod = defaultHandler;
        if (instanceMethod == null) throw new IllegalArgumentException("No method with annotation @StateHandler");
        return instanceMethod;
    }


}
