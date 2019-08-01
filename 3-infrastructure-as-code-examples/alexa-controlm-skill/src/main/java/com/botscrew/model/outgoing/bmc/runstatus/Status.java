package com.botscrew.model.outgoing.bmc.runstatus;

import lombok.Data;

@Data
public class Status {

    private String jobId;
    private String folderId;
    private Integer numberOfRuns;
    private String name;
    private String folder;
    private String type;
    private String status;
    private Boolean held;
    private Boolean deleted;
    private String startTime;
    private String endTime;
    private String orderDat;
    private String ctm;
    private String description;
    private String host;
    private String application;
    private String subApplication;
    private String outputURI;
    private String logURI;

}
