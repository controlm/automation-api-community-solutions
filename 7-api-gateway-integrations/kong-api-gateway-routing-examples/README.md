# Kong API gateway routing examples

An API Gateway can be configured such that features are applied to only 
particular services, routes or requests. 

The following example `kong.yml` file shows some possibilities:

```
services:

- name: ctm-test
  url: https://ctmtest:8446/automation-api/
  routes:
  - name: controlm-api-test
    protocols: ["https"]
    paths:
    - /test/ctmapi
    strip_path: true

- name: ctm-prod
  url: https://ctmprod:8446/automation-api/
  routes:
  - name: controlm-api-prod
    protocols: ["https"]
    paths:
    - /prod/ctmapi
    strip_path: true
  plugins:
  - name: rate-limiting
    config:
      policy: local
      second: 1000
      hour: 1000000

- name: ctm-prod-reports
  url: https://ctmprod:8446/automation-api/reporting/
  routes:
  - name: controlm-reports
    protocols: ["https"]
    paths:
    - /prod/ctmapi/reporting
    strip_path: true
  plugins:
  - name: rate-limiting
    config:
      policy: local
      second: 5
      hour: 1000
```

Lets's assume the organisation's test environment runs on machine `ctmtest`, the
production runs on `ctmprod`, and the Kong API gateway with above configuration 
runs on machine `kongtw`.

Following the above definition, requests to `https://kongtw/test/ctmapi` would 
are routed to the Control-M Automation API in the test environment. 

Requests to `https://kongtw/prod/ctmapi` are routed to the Control-M Automation
API in the production environment. 
A rate limit is set for a maximum of 1000 requests per second and 1 million per 
hour, to prevent runaway tasks from overwhelming the service.

Furthermore, requests to `https://kongtw/prod/ctmapi/reporting` would be limited
5 requests per second or 1000 per hour (whichever comes first). This is done 
because running a big report can have a performance impact, and thus the lower 
limits will prevent this from affecting the system.

When proxying requests, the API gateway selects the longest matching path, thus 
requests to `/prod/ctmapi/reporting/report` will go through the 
`ctm-prod-reports` service rather than the `ctm-prod` service whose shorter path
also matches this request.
