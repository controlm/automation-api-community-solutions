package com.botscrew.service.impl;

import com.botscrew.constant.EnvironmentName;
import com.botscrew.dao.EnvironmentDao;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;
import com.botscrew.service.EnvironmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class EnvironmentServiceImpl implements EnvironmentService {

    private final EnvironmentDao environmentDao;

    @Override
    public Optional<Environment> findUsersCurrentSelected(User user) {
        return findByUserAndCurrentSelected(user,true);
    }

    @Override
    public Optional<Environment> findUsersDefault(User user) {
        return  findByUserAndUsersDefault(user,true);
    }

    @Override
    public Optional<Environment> findByUserAndCurrentSelected(User user, Boolean currentSelected) {
        return environmentDao.findByUserAndCurrentSelected(user, currentSelected);
    }

    @Override
    public Optional<Environment> findByUserAndUsersDefault(User user, Boolean usersDefault) {
        return environmentDao.findByUserAndUsersDefault(user, usersDefault);
    }

    @Override
    public Optional<Environment> findByUserAndEnvironmentName(User user, EnvironmentName environmentName) {
        return environmentDao.findByUserAndEnvironmentName(user, environmentName);
    }

    @Override
    public Optional<Environment> getEnvironmentByUserAndIndex(User user, int index) {
        try{
            return Optional.of(findAllByUser(user).get(index));
        }catch (IndexOutOfBoundsException e){
            return Optional.empty();
        }
    }

    @Override
    public List<Environment> findAllByUser(User user) {
        return environmentDao.findAllByUser(user);
    }

    @Override
    public List<Environment> findAllByUserId(Long userId) {
        return environmentDao.findAllByUserId(userId);
    }

    @Override
    public Optional<Environment> findById(Long id) {
        return environmentDao.findById(id);
    }

    @Override
    public List<Environment> findByEnvironmentNameAndUserId(EnvironmentName environmentName, Long userId) {
        return environmentDao.findByEnvironmentNameAndUserId(environmentName, userId);
    }

    @Override
    public List<Environment> findByEndpointAndUserIdOrUserIdAndEnvironmentName(String endpoint, Long userId, EnvironmentName environmentName) {
        return environmentDao.findByEndpointAndUserIdOrUserIdAndEnvironmentName(endpoint, userId, userId,environmentName);
    }

    @Override
    public Optional<Environment> findByEndpointAndUserIdAndEnvironmentName(String endpoint, Long userId, EnvironmentName environmentName) {
        return environmentDao.findByEndpointAndUserIdAndEnvironmentName(endpoint, userId, environmentName);
    }

    @Override
    public Optional<Environment> findByUserIdAndEnvironmentName(Long userId, EnvironmentName environmentName){
        return environmentDao.findByUserIdAndEnvironmentName(userId, environmentName);
    }

    @Override
    public List<Environment> findByEndpointAndUserId(String endpoint, Long userId){
        return environmentDao.findByEndpointAndUserId(endpoint, userId);
    }

    @Override
    public Environment save(Environment environment) {
        return environmentDao.save(environment);
    }

    @Override
    public void delete(Long id) {
        environmentDao.deleteById(id);
    }

    @Override
    public void saveAll(List<Environment> environments) {
        environmentDao.saveAll(environments);
    }


}
