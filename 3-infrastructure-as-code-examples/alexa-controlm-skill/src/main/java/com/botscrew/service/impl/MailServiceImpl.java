package com.botscrew.service.impl;

import com.botscrew.constant.PropertyKey;
import com.botscrew.entity.User;
import com.botscrew.messaging.MessageHolder;
import com.botscrew.messaging.MessageKey;
import com.botscrew.properties.Property;
import com.botscrew.service.MailService;
import lombok.RequiredArgsConstructor;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import javax.mail.MessagingException;
import javax.mail.internet.MimeMessage;

@Service
@RequiredArgsConstructor
public class MailServiceImpl implements MailService {

    private final Property property;
    private final JavaMailSender javaMailSender;
    private final MessageHolder messageHolder;

    @Override
    public MimeMessage getMimeMessage (String to, String text) {
        MimeMessage mimeMessage = javaMailSender.createMimeMessage();
        MimeMessageHelper mailMsg;
        try {
            mailMsg = new MimeMessageHelper(mimeMessage, true);
            mailMsg.setTo(to);
            mailMsg.setSubject(messageHolder.getMessage(MessageKey.MAIL_SUBJECT));
            mailMsg.setText(text);
        } catch (MessagingException e) {
            System.out.println(e.getMessage());
        }

        return mimeMessage;
    }

    @Async
    @Override
    public void sendMailToRecipient(String text, String RecipientMail) {
        try {
            javaMailSender.send(getMimeMessage(RecipientMail, text));
        } catch (MailSendException e) {
            System.out.println(e.getMessage());
        }
    }

    @Async
    @Override
    public void sendMailWithEnvironments(User user) {
        sendMailToRecipient(messageHolder.getTemplateMessage(MessageKey.MAIL,
                "$user_id$", user.getId().toString(),
                "$base_url$", property.getStringPropertyByKey(PropertyKey.BASE_URL)),
                user.getEmail());
    }
}