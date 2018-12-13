package com.botscrew.config;

import com.botscrew.MainServlet;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.servlet.ServletRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ServletConfiguration {

    @Autowired
    private MainServlet myServlet;

    @Bean
    public ServletRegistrationBean genericCustomServlet() {
        ServletRegistrationBean bean = new ServletRegistrationBean(myServlet, "/api/alexa");
        bean.setLoadOnStartup(1);
        return bean;
    }
}
