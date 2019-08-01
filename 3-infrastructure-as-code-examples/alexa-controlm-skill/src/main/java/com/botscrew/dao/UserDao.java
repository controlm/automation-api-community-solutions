package com.botscrew.dao;

import com.botscrew.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserDao extends JpaRepository<User, Long> {
    User findByAmazonId(String userId);
}
