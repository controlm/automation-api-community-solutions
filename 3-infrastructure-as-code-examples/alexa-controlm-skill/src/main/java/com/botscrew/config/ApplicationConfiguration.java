package com.botscrew.config;

import com.botscrew.constant.PropertyKey;
import com.botscrew.converter.HtmlHttpMessageConverter;
import com.botscrew.properties.Property;
import com.botscrew.service.impl.MySSLSocketFactory;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import javassist.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.apache.http.HttpVersion;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.ClientConnectionManager;
import org.apache.http.conn.scheme.PlainSocketFactory;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.scheme.SchemeRegistry;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.conn.tsccm.ThreadSafeClientConnManager;
import org.apache.http.params.BasicHttpParams;
import org.apache.http.params.HttpParams;
import org.apache.http.params.HttpProtocolParams;
import org.apache.http.protocol.HTTP;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.http.converter.ByteArrayHttpMessageConverter;
import org.springframework.http.converter.ResourceHttpMessageConverter;
import org.springframework.http.converter.StringHttpMessageConverter;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.http.converter.support.AllEncompassingFormHttpMessageConverter;
import org.springframework.http.converter.xml.SourceHttpMessageConverter;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.web.client.ResponseErrorHandler;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.security.KeyStore;
import java.util.Arrays;
import java.util.Properties;

@Configuration
@PropertySource("classpath:text.properties")
@PropertySource("classpath:alexa.properties")
@RequiredArgsConstructor
public class ApplicationConfiguration {

    private final Property property;

    @Bean
    public JavaMailSender javaMailSender() {
        final JavaMailSenderImpl mailSender = new JavaMailSenderImpl();
        mailSender.setHost(property.getStringPropertyByKey(PropertyKey.MAIL_SMTP_GMAIL_COM));
        mailSender.setPort(property.getIntegerPropertyByKey(PropertyKey.MAIL_PORT));
        mailSender.setUsername(property.getStringPropertyByKey(PropertyKey.MAIL_FROM));
        mailSender.setPassword(property.getStringPropertyByKey(PropertyKey.MAIL_PASSWORD));

        final Properties prop = mailSender.getJavaMailProperties();
        prop.put("mail.transport.protocol", property.getStringPropertyByKey(PropertyKey.MAIL_TRANSPORT_PROTOCOL));
        prop.put("mail.smtp.starttls.enable", property.getBooleanPropertyByKey(PropertyKey.MAIL_SMTP_STARTTLS_ENABLE));

        return mailSender;
    }

    private HttpClient getNewHttpClient() {
        try {
            KeyStore trustStore = KeyStore.getInstance(KeyStore.getDefaultType());
            trustStore.load(null, null);

            MySSLSocketFactory sf = new MySSLSocketFactory(trustStore);
            sf.setHostnameVerifier(SSLSocketFactory.ALLOW_ALL_HOSTNAME_VERIFIER);
            HttpParams params = new BasicHttpParams();
            HttpProtocolParams.setVersion(params, HttpVersion.HTTP_1_1);
            HttpProtocolParams.setContentCharset(params, HTTP.UTF_8);
            SchemeRegistry registry = new SchemeRegistry();
            registry.register(new Scheme("http", PlainSocketFactory.getSocketFactory(), 80));
            registry.register(new Scheme("https", sf, 443));
            ClientConnectionManager ccm = new ThreadSafeClientConnManager(params, registry);
            return new DefaultHttpClient(ccm, params);
        } catch (Exception e) {
            return new DefaultHttpClient();
        }
    }

    @Bean
    public RestTemplate restTemplate() {

        final RestTemplate restTemplate = new RestTemplate();
        restTemplate.setErrorHandler(new ResponseErrorHandler(){
            @Override
            public boolean hasError(ClientHttpResponse clientHttpResponse) throws IOException {
                if(HttpStatus.NOT_FOUND.equals(clientHttpResponse.getStatusCode()))return true;
                return false;
            }
            @Override
            public void handleError(ClientHttpResponse clientHttpResponse) throws IOException {
                System.out.println("clientHttpResponse = " + clientHttpResponse);
                throw new IOException(new NotFoundException(""));
            }
        });

        restTemplate.setRequestFactory(new HttpComponentsClientHttpRequestFactory(getNewHttpClient()));
        restTemplate.setMessageConverters(Arrays.asList(new ByteArrayHttpMessageConverter(), new StringHttpMessageConverter(), new ResourceHttpMessageConverter(), new SourceHttpMessageConverter<>(), new AllEncompassingFormHttpMessageConverter(),
                new MappingJackson2HttpMessageConverter(jacksonObjectMapper()), new HtmlHttpMessageConverter()));
        return restTemplate;
    }

//    @Bean
//    public ObjectMapper xmlObjectMapper() {
//        final ObjectMapper objectMapper = new XmlMapper();
//        objectMapper.configure(DeserializationFeature.ACCEPT_SINGLE_VALUE_AS_ARRAY, true);
//        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
//        objectMapper.configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);
//        objectMapper.registerModules(new JavaTimeModule());
//        objectMapper.findAndRegisterModules();
//        return objectMapper;
//    }

    @Bean
    public ObjectMapper jacksonObjectMapper() {
        final ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.configure(DeserializationFeature.ACCEPT_SINGLE_VALUE_AS_ARRAY, true);
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        objectMapper.configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);
        objectMapper.registerModules(new JavaTimeModule());
        objectMapper.findAndRegisterModules();
        return objectMapper;
    }
}
