package com.botscrew.model.outgoing.bmc.runstatus;

import lombok.Data;

import java.util.List;

@Data
public class RunStatusResponse {

    private List<Status> statuses;
    private Integer total;
    private Integer returned;

}
