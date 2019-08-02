package com.botscrew.model.outgoing.bmc;

import com.botscrew.constant.Result;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BmcLoginResponse {

    private Result result;
    private String username;
    private String token;
    private String version;

    public BmcLoginResponse(Result result){
        this.result = result;
    }

}
