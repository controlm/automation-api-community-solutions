package com.botscrew.service;

import com.botscrew.constant.Result;
import com.botscrew.entity.Environment;
import com.botscrew.model.bmc.ResourceSetValResult;
import com.botscrew.model.bmc.ResourceStatusResult;
import com.botscrew.model.bmc.RunStatusResult;
import com.botscrew.model.outgoing.bmc.BmcLoginResponse;

public interface BmcApi {

    BmcLoginResponse login(String environmentUrl, String username, String password);

    void logout(String environmentUrl, String token);

    Result runJob(Environment env, String jobName, String folderName);

    RunStatusResult runStatus(Environment environment, String jobName);

    ResourceStatusResult resourceStatus(Environment environment, String resource);

    ResourceSetValResult resourceSetVal(Environment environment, String resource, String val);
}
