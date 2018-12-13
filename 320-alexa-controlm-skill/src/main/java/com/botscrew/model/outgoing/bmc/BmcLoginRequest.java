package com.botscrew.model.outgoing.bmc;

import com.botscrew.constant.Result;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class BmcLoginRequest {

    private String username;
    private String password;

}
