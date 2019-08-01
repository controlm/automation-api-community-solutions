package com.botscrew.entity;

import com.botscrew.constant.EnvironmentName;
import com.botscrew.model.incoming.EnvironmentModel;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import javax.persistence.*;

@Data
@Entity
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "environment")
public class Environment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String controlM;

    @Column(nullable = false)
    private String endpoint;

    @Column(nullable = false)
    private String username;

    @Column(nullable = false)
    private String password;

    @Column(name = "job_name")
    private String jobName;

    @Column(name = "file_name")
    private String fileName;

    @Column(name = "event_name")
    private String eventName;

    @Column(name = "folder_name")
    private String folderName;

    @Column
    private String value;

    @Column
    private String resource;

    @ManyToOne
    private User user;

    @Column(name = "current_selected")
    private Boolean currentSelected;

    @Column(name = "users_default")
    private Boolean usersDefault;

    @Column(name = "environment_name")
    @Enumerated(EnumType.STRING)
    private EnvironmentName environmentName;

    public Environment(EnvironmentModel environment, User user) {
        id = environment.getId();
        endpoint = environment.getEndpoint();
        username = environment.getUsername();
        password = environment.getPassword();
        jobName = environment.getJobName();
        fileName = environment.getFileName();
        folderName = environment.getFolderName();
        eventName = environment.getEventName();
        value = environment.getValue();
        resource = environment.getResource();
        currentSelected = environment.getCurrentSelected();
        usersDefault = environment.getUsersDefault();
        controlM = environment.getControlM();
        environmentName = environment.getEnvironmentName();
        this.user = user;
    }
}