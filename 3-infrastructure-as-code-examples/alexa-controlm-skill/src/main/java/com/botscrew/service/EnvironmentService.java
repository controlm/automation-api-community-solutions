package com.botscrew.service;

import com.botscrew.constant.EnvironmentName;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;

import java.util.List;
import java.util.Optional;

public interface EnvironmentService {

    Optional<Environment> findUsersCurrentSelected(User user);

    Optional<Environment> findUsersDefault(User user);

    Optional<Environment> findByUserAndCurrentSelected(User user, Boolean currentSelected);

    Optional<Environment> findByUserAndUsersDefault(User user, Boolean usersDefault);

    Optional<Environment> findByUserAndEnvironmentName(User user, EnvironmentName environmentName);

    Optional<Environment> getEnvironmentByUserAndIndex(User user, int index);

    List<Environment> findAllByUser(User user);

    List<Environment> findAllByUserId(Long userId);

    Optional<Environment> findById(Long id);

    List<Environment> findByEnvironmentNameAndUserId(EnvironmentName environmentName, Long userId);

    List<Environment> findByEndpointAndUserIdOrUserIdAndEnvironmentName(String endpoint, Long userId, EnvironmentName environmentName);

    Optional<Environment> findByEndpointAndUserIdAndEnvironmentName(String endpoint, Long userId, EnvironmentName environmentName);

    Optional<Environment> findByUserIdAndEnvironmentName(Long userId, EnvironmentName environmentName);

    List<Environment> findByEndpointAndUserId(String endpoint, Long userId);

    Environment save(Environment environment);

    void delete(Long id);

    void saveAll(List<Environment> environments);
}
