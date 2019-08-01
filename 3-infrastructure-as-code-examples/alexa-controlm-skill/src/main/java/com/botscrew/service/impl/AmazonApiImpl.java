package com.botscrew.service.impl;

import com.botscrew.constant.PropertyKey;
import com.botscrew.model.outgoing.ProfileInfo;
import com.botscrew.properties.Property;
import com.botscrew.service.AmazonApi;
import lombok.AllArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
@AllArgsConstructor
public class AmazonApiImpl implements AmazonApi {

    private final RestTemplate restTemplate;
    private final Property property;

    @Override
    public ProfileInfo profileInfo(String accessToken){
        return restTemplate.getForObject(property.getStringPropertyByKey(PropertyKey.AMAZON_PROFILE_INFO_URL,"$access_token$",accessToken), ProfileInfo.class);
    }

}
