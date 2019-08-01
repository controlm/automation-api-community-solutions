package com.botscrew.service.impl;

import com.botscrew.constant.PropertyKey;
import com.botscrew.constant.Result;
import com.botscrew.entity.Environment;
import com.botscrew.model.bmc.ResourceSetValResult;
import com.botscrew.model.bmc.ResourceStatusResult;
import com.botscrew.model.bmc.RunStatusResult;
import com.botscrew.model.outgoing.bmc.BmcLoginRequest;
import com.botscrew.model.outgoing.bmc.BmcLoginResponse;
import com.botscrew.model.outgoing.bmc.resource.setval.ResourceSetValReq;
import com.botscrew.model.outgoing.bmc.resource.setval.ResourceSetValResponse;
import com.botscrew.model.outgoing.bmc.resource.status.ResourceStatusResponse;
import com.botscrew.model.outgoing.bmc.runjob.RunRequest;
import com.botscrew.model.outgoing.bmc.runstatus.RunStatusResponse;
import com.botscrew.properties.Property;
import com.botscrew.service.BmcApi;
import javassist.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class BmcApiImpl implements BmcApi {

    private final RestTemplate restTemplate;
    private final Property property;

    @Override
    public BmcLoginResponse login(String environmentUrl, String username, String password) {
        HttpHeaders httpHeaders = new HttpHeaders();
        httpHeaders.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<BmcLoginRequest> httpEntity = new HttpEntity<>(new BmcLoginRequest(username, password), httpHeaders);
//        try{
        try {
            ResponseEntity<BmcLoginResponse> response = restTemplate.postForEntity(property.getStringPropertyByKey(PropertyKey.BMC_LOGIN, "$environment_url$", environmentUrl)
                    , httpEntity
                    , BmcLoginResponse.class);
            return HttpStatus.OK.equals(response.getStatusCode())
                    ? setResponseStatus(response.getBody(), Result.OK)
                    : BmcLoginResponse.builder().result(Result.WRONG_PASSWORD).build();
//            }catch (NotFoundException e){
        } catch (RestClientException e) {
            if (IOException.class.equals(e.getCause().getClass())
                    && NotFoundException.class.equals(e.getCause().getCause().getClass()))
                return BmcLoginResponse.builder().result(Result.WRONG_ENDPOINT).build();
            throw e;
        }
//        }catch (HtmlMessageConverterException e){
//            return BmcLoginResponse.builder().result(Result.WRONG_ENDPOINT).build();
//        }
    }

    private BmcLoginResponse setResponseStatus(BmcLoginResponse response, Result result) {
        response.setResult(result);
        return response;
    }

    @Override
    public void logout(String environmentUrl, String token) {
        HttpEntity requestHttpEntity = new HttpEntity(getAuthorizationHeader(token));
        restTemplate.exchange(
                property.getStringPropertyByKey(PropertyKey.BMC_LOGOUT, "$environment_url$", environmentUrl),
                HttpMethod.POST, requestHttpEntity, String.class);
    }

    @Override
    public Result runJob(Environment env, String jobName, String folderName) {
        BmcLoginResponse token = getAccessToken(env);
        return token.getResult() == Result.OK ?
                runJob(token.getToken(), folderName, jobName, env)
                : token.getResult();
    }

    private Result runJob(String token, String folderName, String jobName, Environment env) {
        HttpEntity requestHttpEntity = new HttpEntity(
                RunRequest.builder().folder(folderName).jobs(jobName).ctm(env.getControlM()).build()
                , getAuthorizationHeader(token));
        String url = property.getStringPropertyByKey(PropertyKey.BMC_JOB_RUN, "$environment_url$", env.getEndpoint());
        ResponseEntity<String> response = restTemplate.exchange(
                url,
                HttpMethod.POST, requestHttpEntity, String.class);
        return HttpStatus.OK.equals(response.getStatusCode())
                ? Result.OK
                : HttpStatus.BAD_REQUEST.equals(response.getStatusCode())
                ? Result.WRONG_DATA : Result.UNKNOWN_RESULT;
    }

    @Override
    public RunStatusResult runStatus(Environment environment, String jobName) {
        BmcLoginResponse token = getAccessToken(environment);
        return token.getResult() == Result.OK ?
                runStatus(token.getToken(), jobName, environment)
                : RunStatusResult.builder().result(token.getResult()).build();
    }

    private RunStatusResult runStatus(String token, String jobName, Environment environment) {
        Map<String, String> keys = new HashMap<>();
        keys.put("$environment_url$", environment.getEndpoint());
        keys.put("$job_name$", jobName);
        keys.put("$ctm$", environment.getControlM());
        String url = property.getStringPropertyByKey(PropertyKey.BMC_RUN_STATUS, keys);
        ResponseEntity<RunStatusResponse> response = restTemplate.exchange(url, HttpMethod.GET, new HttpEntity(getAuthorizationHeader(token)), RunStatusResponse.class);
        logout(environment.getEndpoint(), token);
        return HttpStatus.OK.equals(response.getStatusCode())
                ? RunStatusResult.builder().runStatusResponse(response.getBody()).result(Result.OK).build()
                : RunStatusResult.builder().result(Result.UNKNOWN_RESULT).build();
    }

    @Override
    public ResourceStatusResult resourceStatus(Environment environment, String resource) {
        BmcLoginResponse token = getAccessToken(environment);
        return token.getResult() == Result.OK ?
                resourceStatus(token.getToken(), resource, environment)
                : ResourceStatusResult.builder().result(token.getResult()).build();
    }

    private ResourceStatusResult resourceStatus(String token, String resource, Environment environment) {
        ResponseEntity<ResourceStatusResponse[]> response = resourceStatusRequest(environment, resource, token);
        if (HttpStatus.OK.equals(response.getStatusCode()))
            return response.getBody().length == 0
                    ? ResourceStatusResult.builder().result(Result.WRONG_DATA).build()
                    : ResourceStatusResult.builder().resourceStatusResponse(response.getBody()[0]).result(Result.OK).build();
        else return ResourceStatusResult.builder().result(Result.UNKNOWN_RESULT).build();
    }

    @Override
    public ResourceSetValResult resourceSetVal(Environment environment, String resource, String val) {
        BmcLoginResponse token = getAccessToken(environment);
        return token.getResult() == Result.OK ?
                resourceSetVal(token.getToken(), resource, val, environment)
                : ResourceSetValResult.builder().result(token.getResult()).build();
    }

    private ResourceSetValResult resourceSetVal(String token, String resource, String val, Environment environment) {
        ResponseEntity<ResourceSetValResponse> response = resourceSetValRequest(environment, resource, val, token);
        switch (response.getStatusCode()) {
            case OK:
                return ResourceSetValResult.builder().result(Result.OK).message(String.valueOf(response.getBody().getMessage())).build();
            case NOT_FOUND:
                return ResourceSetValResult.builder().result(Result.NOT_FOUND).build();
            case BAD_REQUEST:
                return ResourceSetValResult.builder().result(Result.BAD_REQUEST).build();
            case INTERNAL_SERVER_ERROR:
                return ResourceSetValResult.builder().result(Result.WRONG_DATA).build();
            default:
                return ResourceSetValResult.builder().result(Result.UNKNOWN_RESULT).build();
        }
    }

    private ResponseEntity<ResourceSetValResponse> resourceSetValRequest(Environment environment, String resource, String val, String token) {
        Map<String, String> keys = new HashMap<>();
        keys.put("$environment_url$", environment.getEndpoint());
        keys.put("$resource$", resource);
        keys.put("$ctm$", environment.getControlM());
        String url = property.getStringPropertyByKey(PropertyKey.BMC_RESOURCE_SET_VALUE, keys);
        ResponseEntity<ResourceSetValResponse> response = restTemplate.exchange(url, HttpMethod.POST,
                new HttpEntity(new ResourceSetValReq(val), getAuthorizationHeader(token)), ResourceSetValResponse.class);
        logout(environment.getEndpoint(), token);
        return response;
    }

    private ResponseEntity<ResourceStatusResponse[]> resourceStatusRequest(Environment environment, String resource, String token) {
        Map<String, String> keys = new HashMap<>();
        keys.put("$environment_url$", environment.getEndpoint());
        keys.put("$resource$", resource);
        keys.put("$ctm$", environment.getControlM());
        String url = property.getStringPropertyByKey(PropertyKey.BMC_RESOURCE_STATUS, keys);
        ResponseEntity<ResourceStatusResponse[]> response = restTemplate.exchange(url, HttpMethod.GET, new HttpEntity(getAuthorizationHeader(token)),
                ResourceStatusResponse[].class);
        logout(environment.getEndpoint(), token);
        return response;
    }

    private BmcLoginResponse getAccessToken(Environment environment) {
        return login(environment.getEndpoint(), environment.getUsername(), environment.getPassword());
    }

    private MultiValueMap<String, String> getAuthorizationHeader(String token) {
        HttpHeaders httpHeaders = new HttpHeaders();
        httpHeaders.setContentType(MediaType.APPLICATION_JSON);
        httpHeaders.add("Authorization", "Bearer " + token);
        return httpHeaders;
    }
}
