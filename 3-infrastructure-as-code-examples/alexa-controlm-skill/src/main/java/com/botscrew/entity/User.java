package com.botscrew.entity;

import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;
import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;

@Entity
@Getter
@Setter
@Table(name = "user")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "amazon_id")
    private String amazonId;

    @Column(name = "state")
    @Enumerated(EnumType.STRING)
    private State state;

    @Column(name = "access_token", length = 1024)
    private String accessToken;

    @Column(name = "amazon_name")
    private String amazonName;

    @Column(name = "email")
    private String email;

    @Enumerated(EnumType.STRING)
    private UserVariables userVariables;

    @Column(name = "first_time_user")
    private Boolean firstTimeUser = true;

    @Column(name = "wrong_word_position")
    private Integer wrongWordPosition;

    @Column(name = "current_file_name")
    private String currentFileName = "";

    @Column(name = "current_job_name")
    private String currentJobName = "";

    @Column(name = "current_folder_name")
    private String currentFolderName = "";

    @Column(name = "current_event_name")
    private String currentEventName = "";

    @Column(name = "current_value")
    private String currentValue = "";

    @Column(name = "current_resource")
    private String currentResource = "";

    public User(String amazonId) {
        this.amazonId = amazonId;
        this.state = State.DEFAULT_STATE;
    }

    public User(String amazonId, String accessToken) {
        this.amazonId = amazonId;
        this.accessToken = accessToken;
        this.state = State.DEFAULT_STATE;
    }

    public User() {
    }
}
