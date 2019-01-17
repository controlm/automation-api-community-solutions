package com.botscrew.model.outgoing;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class ProfileInfo {

    @JsonProperty("user_id")
    private String userId;
    private String name;
    private String email;
}
