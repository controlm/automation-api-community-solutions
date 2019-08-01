package com.botscrew.model.bmc;

import com.botscrew.constant.Result;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class ResourceSetValResult {

    private String message;
    private Result result;
}
