package com.botscrew.controller;

import com.botscrew.entity.Environment;
import com.botscrew.model.incoming.DeleteEnvRequest;
import com.botscrew.model.incoming.EnvironmentModel;
import com.botscrew.model.incoming.SetDefaultEnvRequest;
import com.botscrew.service.EnvironmentService;
import com.botscrew.service.UserService;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.apache.catalina.servlet4preview.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.ModelAndView;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

@CrossOrigin("*")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api")
public class EnvironmentsController {

    private final UserService userService;
    private final EnvironmentService environmentService;


    @RequestMapping(value = "/cookie", method = RequestMethod.GET)
    public ModelAndView saveEnvironmentHandler(HttpServletRequest httpServletRequest) {
        return new ModelAndView("index.html");
    }

    @RequestMapping("/environments/{id}")
    public List<Environment> environments(@PathVariable("id") Long id) {
        return environmentService.findAllByUserId(id);
    }


    @RequestMapping(value = "/environments/default", method = RequestMethod.POST)
    public ResponseEntity deleteEnvironment(@RequestBody SetDefaultEnvRequest env) {
        try {
            userService.setAndSaveDefaultEnvironment(userService.findById(env.getUserId()).get()
                    , environmentService.findById(env.getEnvironmentId()).get());
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }

    }

    @RequestMapping(value = {"/environments/{id}"}, method = RequestMethod.POST)
    public ResponseEntity createEnvironment(@PathVariable("id") Long userId, @RequestBody EnvironmentModel environment) {
        return checkOnUnique(environment, userId)
                .orElseGet(()->{
                    Environment e = environmentService.save(new Environment(environment, userService.findById(userId).get()));
                    return new ResponseEntity(e.getId(), HttpStatus.OK);
                });
//        Optional<Environment> environmentOptional = obtainEnvId(environment, userId);
//        return environmentOptional.map(environment1 -> ).orElse(new ResponseEntity<>(HttpStatus.BAD_REQUEST));
    }

//
//    private Optional<Environment> obtainEnvId(EnvironmentModel environment, Long userId) {
//        List<Environment> environments = environmentService.findByEndpointAndUserIdOrUserIdAndEnvironmentName(environment.getEndpoint(), userId, environment.getEnvironmentName());
//
//        return environments.isEmpty() ?
//                Optional.of() :
//                Optional.empty();
//
//    }

    @RequestMapping(value = "/environments/delete", method = RequestMethod.POST)
    public ResponseEntity deleteEnvironment(@RequestBody DeleteEnvRequest env) {
        System.out.println(env.getId());
        try {
            environmentService.delete(env.getId());
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @RequestMapping(value = "/environments/save/{id}", method = RequestMethod.POST)
    public ResponseEntity saveEnvironmentHandler(@PathVariable("id") Long userId, @RequestBody EnvironmentModel environment) {
        return checkOnUnique(environment, userId)
                .orElse(saveEnvironment(environment, userId));
    }

    private ResponseEntity saveEnvironment(EnvironmentModel environment, Long userId) {
        environmentService.save(new Environment(environment, userService.findById(userId).get()));
        return ResponseEntity.ok().build();
    }

    private Optional<ResponseEntity> checkOnUnique(EnvironmentModel environment, Long userId) {
        List<Environment> byEndpointAndUserId = environmentService.findByEndpointAndUserId(environment.getEndpoint(), userId);
        byEndpointAndUserId.removeIf(e -> e.getId().equals(environment.getId()));
        if (!byEndpointAndUserId.isEmpty())
            return Optional.of(ResponseEntity.badRequest().body(new Qwer("Seems that environment with such endpoint already exists. Please, type unique endpoint.")));

        List<Environment> byEnvironmentNameAndUserId = environmentService.findByEnvironmentNameAndUserId(environment.getEnvironmentName(), userId);
        byEnvironmentNameAndUserId.removeIf(e -> e.getId().equals(environment.getId()));
        if (!byEnvironmentNameAndUserId.isEmpty())
            return Optional.of(ResponseEntity.badRequest().body(new Qwer("Seems that environment with such name already exists. Please, choose unique name.")));

        return Optional.empty();
    }
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    class Qwer{
        private String message;
    }
}
