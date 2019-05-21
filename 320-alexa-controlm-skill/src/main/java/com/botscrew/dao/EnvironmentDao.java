package com.botscrew.dao;

import com.botscrew.constant.EnvironmentName;
import com.botscrew.entity.Environment;
import com.botscrew.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface EnvironmentDao extends JpaRepository<Environment, Long> {

    List<Environment> findByEnvironmentNameAndUserId(EnvironmentName environmentName, Long userId);

    List<Environment>findByEndpointAndUserIdOrUserIdAndEnvironmentName(String endpoint, Long userId, Long userId1, EnvironmentName environmentName);

    Optional<Environment> findByUserAndEnvironmentName(User user, EnvironmentName environmentName);

    Optional<Environment> findByEndpointAndUserIdAndEnvironmentName(String endpoint, Long userId, EnvironmentName environmentName);

    Optional<Environment> findByUserIdAndEnvironmentName(Long userId, EnvironmentName environmentName);

    Optional<Environment> findByUserAndCurrentSelected(User user, Boolean currentSelected);

    Optional<Environment> findByUserAndUsersDefault(User user, Boolean usersDefault);

    List<Environment> findAllByUser(User user);

    List<Environment> findAllByUserId(Long userId);

    List<Environment> findByEndpointAndUserId(String endpoint, Long userId);
}
