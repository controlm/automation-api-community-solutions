package com.botscrew.service;

import com.botscrew.entity.User;
import org.springframework.scheduling.annotation.Async;

import javax.mail.internet.MimeMessage;

public interface MailService {
    MimeMessage getMimeMessage(String to, String text);

    void sendMailToRecipient(String text, String RecipientMail);

    @Async
    void sendMailWithEnvironments(User user);
}
