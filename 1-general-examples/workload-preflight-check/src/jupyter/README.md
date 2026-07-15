# Control-M Operations Jupyter Notebooks

A comprehensive toolkit for operations teams to interact with Control-M automation API for inventory management and testing.

## Overview

This project provides Jupyter notebooks that expose Control-M automation API functionality to operations teams, enabling them to:

- **Check Control-M inventory** - servers, agents, hostgroups, connection profiles, run-as users
- **Test agent connectivity** - ping agents to verify availability and status  
- **Test connection profiles** - validate connection profile configurations
- **Export data** - generate reports in JSON and CSV formats for analysis

## Educational Goals

**Important: This toolkit is designed for educational and learning purposes, not production use.**

The primary goal is to demonstrate how to interact with Control-M automation API using Python, providing:

- **Learning Platform**: Understand Control-M API patterns and best practices through interactive notebooks
- **Code Examples**: Real-world Python code showing API authentication, data collection, and testing workflows
- **API Exploration**: Safe environment to experiment with Control-M automation API calls
- **Knowledge Transfer**: Foundation for building your own custom Control-M automation tools and solutions

Use this knowledge to build your own production-ready applications or adapt the patterns for your specific organizational needs. The notebooks serve as educational templates and reference implementations rather than production-ready systems.

## Architecture

The toolkit consists of three main notebooks:

1. **`01_ctm-config.ipynb`** - Interactive configuration setup
2. **`02_ctm.ipynb`** - Inventory data collection  
3. **`03_ctm-monitoring.ipynb`** - Interactive testing and monitoring

## Prerequisites

### System Requirements
- Python 3.7 or higher
- Jupyter Notebook or JupyterLab
- Network access to Control-M Enterprise Manager
- Control-M Automation API token

### Required Python Packages
After copying the files to your Jupyter environment, install dependencies using:
```bash
pip install -r requirements.txt
```

Required packages:
- `pandas` - Data analysis and manipulation
- `requests` - HTTP library for API calls

### Control-M Requirements
- Control-M automation API access
- Valid API authentication token (base64 encoded)
- Control-M Enterprise Manager hostname and port
- Appropriate permissions to access:
  - Server configurations
  - Agent information
  - Connection profiles
  - Host groups
  - Run-as users

## Quick Start Guide

### Step 1: Copy Notebooks to Jupyter Environment
1. Copy the notebook files from the development server to your Jupyter working directory:
   - Copy `src/01_ctm-config.ipynb` → `01_ctm-config.ipynb`
   - Copy `src/02_ctm.ipynb` → `02_ctm.ipynb`
   - Copy `src/03_ctm-monitoring.ipynb` → `03_ctm-monitoring.ipynb`
   - Copy `src/requirements.txt` → `requirements.txt`
2. Install required Python packages in your Jupyter environment:
   ```bash
   pip install -r requirements.txt
   ```

### Step 2: Configuration Setup
1. Open and run `01_ctm-config.ipynb` in your Jupyter environment
2. Execute all cells in order
3. Use the interactive form to enter:
   - **API Token**: Control-M authentication token
   - **Hostname**: Control-M Enterprise Manager hostname (e.g., `ctm.company.com`)
   - **Port**: HTTPS port (typically `443` or `8443`)
4. Click "Save Configuration" to create `.env` file
5. Click "Test Connection" to verify settings

### Step 3: Collect Inventory Data
1. Open and run `02_ctm.ipynb` in your Jupyter environment
2. Execute all cells to collect comprehensive inventory:
   - Control-M servers and their status
   - Agent information (name, OS, version, status, hostgroups)
   - Connection profiles (SFTP, AS2, S3, Azure, etc.)
   - Host groups and member assignments
   - Run-as user configurations

### Step 4: Interactive Testing and Monitoring
1. Open and run `03_ctm-monitoring.ipynb` in your Jupyter environment
2. Use interactive controls to:
   - Select agents from dropdown menu
   - Ping agents to test connectivity
   - Select connection profiles to test
   - Validate connection profile configurations

## Detailed Usage Instructions

### Configuration Management (01_ctm-config.ipynb)

#### Environment Variables
The notebook creates a `.engineer/config/.env` file (relative to `src/`) with the following variables:
```bash
baseUrl=<https://control-m-hostname/automation-api>
apiKey=<token>
CTM_SERVER=<control-m-server-name>
```

#### Interactive Configuration
- **Validation**: Real-time validation of base URL, server name, and token format
- **Connection Testing**: Verifies API connectivity before saving
- **Secure Storage**: Credentials stored in local `.engineer/config/.env` file

#### Troubleshooting Common Issues
| Issue | Solution |
|-------|----------|
| Invalid base URL format | Use full URL format (e.g., `https://ctm.company.com/automation-api`) |
| Connection timeout | Check firewall settings and port accessibility |
| Authentication failure | Verify API token is valid and not expired |
| Certificate errors | Ensure SSL certificates are properly configured |

### Inventory Collection (02_ctm.ipynb)

#### Data Collection Process
The notebook systematically collects:

1. **Server Information**
   - Server names, hostnames, states
   - Connection status and availability

2. **Agent Details**
   - Agent names, operating systems, versions
   - Current status and server assignments
   - Host group memberships

3. **Connection Profiles**
   - Profile names, types, and configurations
   - Supported destinations (SFTP, AS2, S3, Azure, etc.)
   - Authentication and connection parameters

4. **Host Groups**
   - Group names and member agents
   - Server assignments

5. **Run-as Users**
   - User accounts configured for job execution
   - Server-specific assignments

#### Generated Output Files

All collected data is written to `.engineer/inventory/` (relative to `src/`, alongside
`.engineer/config/` and `.engineer/logs/`) so code in `jupyter/` stays separate from the data and
logs it produces — the same split the PowerShell script (`ctm-preflight.ps1`) already uses for its
`LOG_FOLDER`. This directory is gitignored; nothing under it gets committed.

##### JSON Files (in `.engineer/inventory/`)
- `servers.json` - Complete server configurations
- `agents_<server>.json` - Agent details per server
- `connection_profiles.json` - All connection profiles
- `hostgroups_<server>.json` - Host group configurations per server
- `runasusers_<server>.json` - Run-as user configurations per server

##### CSV Files (in `.engineer/inventory/`)
- `ctm_servers.csv` - Server data in tabular format
- `ctm_agents.csv` - Agent information
- `ctm_connection_profiles.csv` - Connection profile details
- `ctm_hostgroups.csv` - Host group data
- `ctm_runasusers.csv` - Run-as user information

##### Master Inventory File
- `.engineer/inventory/ctm-inventory.json` - Comprehensive inventory with metadata (this is the
  file `03_ctm-monitoring.ipynb` reads):
  - Unique UUID for tracking
  - Collection timestamp
  - System information
  - Structured data summary
  - Destination analysis by type

#### Performance Considerations
- **Fast Collection Mode**: Basic inventory without ping tests for speed
- **Bulk Processing**: Efficient API calls to minimize execution time
- **Error Handling**: Continues collection even if individual components fail
- **Progress Tracking**: Real-time status updates during collection

### Interactive Testing and Monitoring (03_ctm-monitoring.ipynb)

#### Agent Testing Features

##### Ping Tests
- **Purpose**: Verify agent connectivity and availability
- **Process**: 
  1. Select agent from dropdown (shows server and status)
  2. Click "Ping Agent" button
  3. View detailed results including response time and availability status
- **Output**: JSON response with ping results and agent status

##### Connection Profile Testing
- **Purpose**: Validate connection profile configurations
- **Process**:
  1. Select connection profile from dropdown (shows type and hostname)
  2. Select agent to perform the test
  3. Click "Test Connection Profile" button
  4. View detailed test results
- **Supported Types**: SFTP, AS2, S3, Azure, GCS, SharePoint, Local File Transfer

#### Test Result Interpretation

##### Successful Agent Ping
```json
{
  "success": true,
  "agent": "agent_name",
  "server": "server_name", 
  "available": true,
  "message": "Agent is available",
  "timestamp": "2024-01-01 10:00:00"
}
```

##### Failed Connection Profile Test
```json
{
  "success": false,
  "connection_profile": "profile_name",
  "error": "Connection timeout or authentication failure",
  "timestamp": "2024-01-01 10:00:00"
}
```

## Operational Procedures

### Daily Inventory Checks
1. Run configuration notebook if credentials need updates
2. Execute inventory collection notebook (02_ctm.ipynb)
3. Review generated CSV files for:
   - Agent status changes
   - New or removed servers
   - Connection profile modifications
   - Host group membership changes

### Weekly Health Checks
1. Use monitoring notebook (03_ctm-monitoring.ipynb) to:
   - Ping all critical agents
   - Test key connection profiles
   - Verify connectivity to external systems
2. Document any failures for investigation
3. Update inventory documentation as needed

### Monthly Reporting
1. Generate comprehensive inventory reports
2. Analyze destination connectivity trends
3. Review and update connection profiles
4. Validate run-as user configurations

## Data Security and Compliance

### Credential Management
- API tokens stored in local `.env` files only
- No credentials embedded in notebook code
- Support for environment variable overrides

### Data Handling
- Inventory data contains system configuration information
- Connection profiles may include hostnames and usernames (no passwords)
- All data stored locally - no external transmission
- Collected data lives under `.engineer/inventory/`, separate from the notebook code in
  `jupyter/` and from credentials in `.engineer/config/`; both are gitignored

### Access Control
- Notebooks require valid Control-M API credentials
- Access limited to configured Control-M permissions
- Read-only operations - no configuration changes made

## Troubleshooting Guide

### Common Connection Issues

#### SSL/Certificate Problems
- **Symptom**: SSL verification errors
- **Solution**: Ensure Control-M certificates are properly installed
- **Workaround**: Contact system administrator for certificate updates

#### Network Connectivity
- **Symptom**: Connection timeouts or unreachable host
- **Solution**: Verify network connectivity and firewall rules
- **Check**: Ping hostname and test port accessibility

#### Authentication Failures
- **Symptom**: HTTP 401 or 403 errors
- **Solution**: Verify API token validity and permissions
- **Action**: Contact Control-M administrator for token renewal

### Data Collection Issues

#### Empty Results
- **Cause**: Insufficient permissions or no data available
- **Solution**: Verify user has read access to all Control-M components
- **Check**: Review Control-M user role assignments

#### Partial Data Collection
- **Cause**: Some servers or agents may be unavailable
- **Solution**: Review error messages and retry for failed components
- **Action**: Check individual server status and connectivity

#### Connection Profiles Error: 500

- **Symptom**: `02_ctm.ipynb` prints `❌ Connection profiles error: 500` while `/config/servers` succeeds
- **Cause**: `GET /deploy/connectionprofiles/centralized` without a `type` filter implicitly
  queries name `*` across every connection profile type at once. If the environment has connection
  profiles of different types that share the same name, the EM rejects the whole request with a 500
  and a body like:

  ```text
  centralized connection profiles with name '*'
  Error message: Multiple connection profiles of different types were detected as having the same
  name. Data can be obtained only with unique names at a time. Adjust your filter by excluding
  duplicate names
  ```

  This is separate from the Configuration service used by `/config/*`, which is why servers/agents
  can still succeed. **Note**: scoping by `type` alone (e.g. `CP_TYPE_FILTER = "FileTransfer"`)
  only avoids this if no two profiles *of that same type* share a name — if duplicate names exist
  within the filtered type too, you'll still hit this error and need to query by `name` as well
  (one profile at a time, as `ctm-preflight.ps1`'s `Get-CtmConnectionProfile` does).
- **Solution**: `type` and `name` are both **required** query parameters on this endpoint — leaving
  `name` off doesn't error, it just silently returns zero profiles, which is easy to mistake for a
  permissions or empty-environment problem. The notebook now sends both, via `CP_TYPE_FILTER =
  "FileTransfer"` and `CP_NAME_FILTER = "*"` (set near the top of the collection cell). This matches
  the Postman collection's "Get centralized deployed connection profile" request
  (`?type=FileTransfer&name=*`) and the scoping already used by `ctm-preflight.ps1`. `CP_NAME_FILTER`
  supports `*`/`?` wildcards and comma-separated names, same as `name` everywhere else in this API.
  If you still see a 500 with both filters applied, the printed response body (also saved by the
  `print(cp_response.text[:500])` line) will contain the EM's actual error detail — check the EM's
  Deploy/CCM service logs for the matching stack trace.

### Performance Issues

#### Slow Collection
- **Cause**: Large number of agents or network latency
- **Solution**: Monitor execution progress and allow adequate time
- **Optimization**: Consider running during off-peak hours

#### Memory Usage
- **Cause**: Large datasets being processed
- **Solution**: Ensure adequate system memory available
- **Alternative**: Process servers individually if needed

## API Reference

### Control-M Automation API Endpoints Used

#### Configuration Endpoints
- `GET /config/servers` - Retrieve server list
- `GET /config/server/{server}/agents` - Get agents for specific server
- `GET /config/server/{server}/hostgroups/agents` - Get host groups
- `GET /config/server/{server}/runasusers` - Get run-as users

#### Connection Profile Endpoints  
- `GET /deploy/connectionprofiles/centralized` - Get centralized connection profiles
  - `type` and `name` are both **required** query params on this endpoint. `02_ctm.ipynb` sets
    these via the `CP_TYPE_FILTER` (default `"FileTransfer"`) and `CP_NAME_FILTER` (default `"*"`)
    variables near the top of the collection cell — matches the Postman collection's
    `?type=FileTransfer&name=*` request. Other valid `type` values include `Database`, `Hadoop`,
    `AWS`, `Azure`, `Informatica`, `SAP`, or `ApplicationIntegrator:<customType>`; `*` also works
    for `type` but risks a `500` if two profiles of different types share the same name (see
    Troubleshooting below). `name` supports `*`/`?` wildcards and comma-separated names.
- `POST /deploy/connectionprofile/centralized/test/{type}/{name}/{server}/{agent}` - Test connection profile

#### Monitoring Endpoints
- `POST /config/server/{server}/agent/{agent}/ping` - Ping specific agent

### Response Formats
All API responses are in JSON format with appropriate HTTP status codes:
- `200` - Success
- `401` - Authentication failure
- `403` - Insufficient permissions
- `404` - Resource not found
- `500` - Server error

## Support and Maintenance

### Regular Maintenance Tasks
1. **Weekly**: Update API tokens if they expire
2. **Monthly**: Review and clean up old inventory files
3. **Quarterly**: Update notebook dependencies and test compatibility

### Getting Help
- **Technical Issues**: Contact your Control-M system administrator
- **API Questions**: Refer to Control-M Automation API documentation
- **Notebook Problems**: Check Jupyter logs and Python environment

### Version Information
- **Author**: Control-M Software Engineering Team - SIGMA
- **Email**: orchestrator@bmc.com  
- **Version**: 1.10.0
- **License**: Apache 2.0

### Warranty Disclaimer
This software is provided "AS IS" without warranty of any kind. Use at your own risk.

---

## License

Licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.
