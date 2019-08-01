package com.botscrew.service;

import com.botscrew.model.outgoing.ProfileInfo;

public interface AmazonApi {

    ProfileInfo profileInfo(String accessToken);
}
