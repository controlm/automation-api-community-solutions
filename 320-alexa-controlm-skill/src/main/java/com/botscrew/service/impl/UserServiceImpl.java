package com.botscrew.service.impl;

import com.amazon.ask.dispatcher.request.handler.HandlerInput;
import com.botscrew.constant.PropertyKey;
import com.botscrew.constant.State;
import com.botscrew.dao.UserDao;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;
import com.botscrew.model.outgoing.ProfileInfo;
import com.botscrew.properties.Property;
import com.botscrew.service.AmazonApi;
import com.botscrew.service.EnvironmentService;
import com.botscrew.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.Optional;
import java.util.function.Consumer;

@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserDao userDao;
    private final Property property;
    private final AmazonApi amazonApi;
    private final EnvironmentService environmentService;

    @Override
    public void refreshUserField(User user, Consumer<String> setter) {
        setter.accept("");
        save(user);
    }

    @Override
    public void setAndSaveCurrentEnvironment(User user, Environment environment) {
        environmentService.findUsersCurrentSelected(user)
                .map(e ->{
                    e.setCurrentSelected(false);
                    environment.setCurrentSelected(true);
                    environmentService.saveAll(Arrays.asList(e, environment));
                    return null;
                })
                .orElseGet(()->{
                    environment.setCurrentSelected(true);
                    return environmentService.save(environment);
                });
    }

    @Override
    public void setAndSaveDefaultEnvironment(User user, Environment environment) {
        environmentService.findUsersDefault(user)
                .map(e ->{
                    e.setUsersDefault(false);
                    environment.setUsersDefault(true);
                    environmentService.saveAll(Arrays.asList(e, environment));
                    return null;
                })
                .orElseGet(()->{
                    environment.setUsersDefault(true);
                    return environmentService.save(environment);
                });
    }

    @Override
    public User createUserIfNotExists(HandlerInput input) {
        String amazonId = input.getRequestEnvelope().getSession().getUser().getUserId();
        User user = userDao.findByAmazonId(amazonId);
        if (property.getBooleanPropertyByKey(PropertyKey.ACCOUNT_LINKING_ON)) {
            String accessToken = input.getRequestEnvelope().getContext().getSystem().getUser().getAccessToken();
            return user == null ? createAndSaveNewUser(amazonId, accessToken) : updateAccessToken(user, accessToken);
        } else {
            return user == null ? createAndSaveNewUser(amazonId) : user;
        }
    }

    private User updateAccessToken(User user, String accessToken) {
        user.setAccessToken(accessToken);
        return save(user);
    }

    @Override
    public void changeState(User user, State state) {
        user.setState(state);
        userDao.save(user);
    }

    private User createAndSaveNewUser(String userId) {
        User user = new User(userId);
        return userDao.save(user);
    }

    private User createAndSaveNewUser(String userId, String accessToken) {
        User user = new User(userId, accessToken);
        ProfileInfo profileInfo = amazonApi.profileInfo(accessToken);
        user.setAmazonName(profileInfo.getName());
        user.setEmail(profileInfo.getEmail());
        return userDao.save(user);
    }

    @Override
    public Optional<User> findById(Long id) {
        return userDao.findById(id);
    }

    @Override
    public User save(User user) {
        return userDao.save(user);
    }


}
