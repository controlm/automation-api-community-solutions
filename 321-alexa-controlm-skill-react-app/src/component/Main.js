import React from 'react';
import "./Main.css";
import Environment from "./Environment";
import MyInput from "./MyInput";
import Menu from "./Menu";
import DeleteEnvironmentModal from "./DeleteEnvironmentModal";
import SwitchEnvironmentModal from "./SwitchEnvironmentModal";
import SetDefaultModal from "./SetDefaultModal";
import isUrl from 'is-url';
import {BASEURL} from '../ExternalFunction';

const envOptions = [
    {value: '', label: 'Select environment name'},
    {value: 'Development', label: 'Development'},
    {value: 'Test', label: 'Test'},
    {value: 'QA', label: 'QA'},
    {value: 'Production', label: 'Production'},
    {value: 'Staging', label: 'Staging'}
];

class Main extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            endpointErrorShown: false,
            showEnvironmentAlreadyExistError: false,
            showSetDefaultModal: false,
            showDeleteEnvModal: false,
            showSwitchEnvironmentModal: false,
            // selectedEnvName: envOptions[0],
            deleteBtnImg: 'img/deleteBtn.png',
            closeModal: 'img/closeModal.png',
            activeTab: 0,
            activeEnvironment: {},
            environments: [],
        };
    };

    setEnvironmentAlreadyExistState = (showError) => {
        this.setState({showEnvironmentAlreadyExistError: showError});
    };

    setEnvironments = (environments) => {
        if (environments.length === 0) {
            environments = [{}];
        }
        this.setState({
            environments: environments,
            activeEnvironment: {...environments[this.state.activeTab]}
        });
    };

    loadData = () => {
        const self = this;
        fetch(BASEURL + 'api/environments/' + this.props.match.params.id)
            .then(
                function (response) {
                    if (response.status !== 200) {
                        console.log('Looks like there was a problem. Status Code: ' +
                            response.status);
                        return;
                    }
                    response.json().then(function (data) {
                        self.setEnvironments(data);
                    });
                }
            )
            .catch(function (err) {
                console.log('Fetch Error :-S', err);
            });
    };

    componentDidMount() {
        this.loadData();
    };

    deleteEnv = () => {
        this.setState({
            showDeleteEnvModal: true
        });
        // let copyState = this.state.environments;
        // copyState.splice(index, 1);
        // this.setState({
        //     environment: copyState
        // });
    };

    generateUniqueKey = () => {
        let uniqueKey;
        while (1) {
            uniqueKey = Math.random();
            if (this.state.environments.findIndex((elem) => {
                return uniqueKey === elem.key;
            }) === -1) {
                break;
            }
        }
        return uniqueKey;
    };

    changeEnvironmentProp = (value, propName) => {
        let environmentCopy = this.state.activeEnvironment;
        environmentCopy[propName] = value;
        this.setState({
            activeEnvironment: environmentCopy
        });
    };

    onMenuTabClick = (index) => {
        if (this.compareActiveEnvironments()) {
            let stateCopy = this.state;
            stateCopy.activeTab = index;
            stateCopy.endpointErrorShown = false;
            stateCopy.showEnvironmentAlreadyExistError = false;
            stateCopy.activeEnvironment = {...(stateCopy.environments[index])};
            this.setState(stateCopy);
        } else {
            this.setState({
                switchEnvironmentModalLinkedTab: index,
                showSwitchEnvironmentModal: true
            })
        }
    };
    findCurrentEnvironment = () => {
        let currentEnv = this.state.environments[this.state.activeTab];
        return currentEnv === undefined ?
            "" : currentEnv.environmentName;
    };

    closeDeleteModal = () => {
        let stateCopy = this.state;
        stateCopy.showDeleteEnvModal = false;
        this.setState(stateCopy);
    };

    environmentCreated = () => {
        this.loadData();
    };

    getCorrectFieldValue = (fieldName) => {
        let res = this.state.activeEnvironment[fieldName] === null ? "" : this.state.activeEnvironment[fieldName];
        return res;
    };

    deleteEnvironment = (id) => {
        const self = this;
        fetch(BASEURL + 'api/environments/delete', {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: id
            })
        })
            .then(
                function (response) {
                    if (response.status === 400) {
                        self.setEnvironmentAlreadyExistState(true);
                        return;
                    }
                    if (response.status === 200) {
                        self.synchronizeWithBack();
                        self.setState({
                            activeTab: 0,
                            showDeleteEnvModal: false
                        });
                    }
                }
            )
            .catch(function (err) {
                console.log('Fetch Error :-S', err);
            });
    };

    synchronizeWithBack() {
        this.loadData();
        if ((this.state.activeTab + 1) > this.state.environments.length) {
            this.setState({
                activeTab: 0
            });
        }
    };

    deleteHandler = () => {
        this.deleteEnvironment(this.state.activeEnvironment.id);
    };

    saveEnv = (event) => {
        event.preventDefault();
        if (!isUrl(this.state.activeEnvironment.endpoint)) {
            this.setState({endpointErrorShown: true});
            return;
        }

        let self = this;
        fetch(BASEURL + 'api/environments/save/' + this.props.match.params.id, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(self.state.activeEnvironment)
        })
            .then(
                function (response) {
                    if (response.status === 400) {
                        response.json().then((data)=>{
                            self.setState({
                                showEnvironmentAlreadyExistError: true,
                                error: data.message
                            });
                        });
                    }
                    if (response.status === 200) {
                        // this.setState({showEnvironmentAlreadyExistError:false});
                        self.synchronizeWithBack();
                    }
                }
            )
            .catch(function (err) {
                console.log('Fetch Error :-S', err);
            });
    };

    compareActiveEnvironments = () => {
        if (this.state.environments.length === 0) return true;
        let q = this.state.activeEnvironment.id === this.state.environments[this.state.activeTab].id &&
            this.state.activeEnvironment.controlM === this.state.environments[this.state.activeTab].controlM &&
            this.state.activeEnvironment.environmentName === this.state.environments[this.state.activeTab].environmentName &&
            this.state.activeEnvironment.username === this.state.environments[this.state.activeTab].username &&
            this.state.activeEnvironment.password === this.state.environments[this.state.activeTab].password &&
            this.state.activeEnvironment.endpoint === this.state.environments[this.state.activeTab].endpoint &&
            this.state.activeEnvironment.jobName === this.state.environments[this.state.activeTab].jobName &&
            this.state.activeEnvironment.folderName === this.state.environments[this.state.activeTab].folderName &&
            this.state.activeEnvironment.fileName === this.state.environments[this.state.activeTab].fileName &&
            this.state.activeEnvironment.eventName === this.state.environments[this.state.activeTab].eventName &&
            this.state.activeEnvironment.value === this.state.environments[this.state.activeTab].value &&
            this.state.activeEnvironment.resource === this.state.environments[this.state.activeTab].resource;
        return q;
    };

    switchEnvHandler = () => {
        this.setState({
            showEnvironmentAlreadyExistError: false,
            endpointErrorShown: false,
            activeTab: this.state.switchEnvironmentModalLinkedTab,
            activeEnvironment: {...(this.state.environments[this.state.switchEnvironmentModalLinkedTab])},
            showSwitchEnvironmentModal: false
        });
    };
    closeSwitchModal = () => {
        this.setState({
            showSwitchEnvironmentModal: false
        });
    };

    setDefault = () => {
        const self = this;
        fetch(BASEURL + 'api/environments/default', {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                userId: self.props.match.params.id,
                environmentId: self.state.activeEnvironment.id
            })
        })
            .then(
                function (response) {
                    self.setState({showSetDefaultModal: false});
                    self.synchronizeWithBack();
                    // if (response.status === 400) {
                    //     self.setEnvironmentAlreadyExistState(true);
                    //     return;
                    // }
                    // if (response.status === 200) {
                    //     self.synchronizeWithBack();
                    //     self.setState({
                    //         activeTab: 0,
                    //         showDeleteEnvModal: false
                    //     });
                    // }
                }
            )
            .catch(function (err) {
                console.log('Fetch Error :-S', err);
            });
    };

    closeSetDefaultModal = () => {
        this.setState({showSetDefaultModal: false});
    };

    setAsDefaultBtn = () => {
        if (this.state.environments.findIndex(e => {
            return e.usersDefault
        }) === -1) {
            this.setDefault();
        } else {
            this.setState({showSetDefaultModal: true});
        }
    };

    getEnvNameOptions = () => {
        return envOptions.map((option) => {
            return <option value={option.value}>{option.label}</option>
        })
    };

    envNameHandleChange = (event) => {
        let stateCopy = this.state;
        stateCopy.activeEnvironment.environmentName = event.target.value;
        this.setState(stateCopy);
    };

    environmentNameWithSelect = () => {
        // ""+(this.state.environments.findIndex(e=>{return e.usersDefault})+1)
        return <div className="environment-name-container">
            <span className="env-name">Environment name </span>
            <select className="environment-name-select"
                    required
                    value={this.state.activeEnvironment.environmentName}
                    onChange={this.envNameHandleChange}>
                {this.getEnvNameOptions()}
            </select>
        </div>;
    };

    findDefaultEnv = () => {
        let env = this.state.environments.find((e) => {
            return e.usersDefault;
        });
        return env === undefined ? null : env.environmentName;
    };

    render() {
        return <div className="doc">
            <div className="show-environment-already-exist-error"
                 style={{display: this.state.showEnvironmentAlreadyExistError ? "flex" : "none"}}>
                <div className="show-environment-already-exist-error-text-container">
                    <span className="show-environment-already-exist-error-text">{this.state.error}</span>
                </div>
                <div className="show-environment-already-exist-error-close-btn-container">
                    <img className="modal-close-img" src={this.state.closeModal}
                         onClick={() => {
                             this.setEnvironmentAlreadyExistState(false)
                         }}/>
                </div>

            </div>
            <div className="main-container">
                <Menu onClick={(index) => {
                    this.onMenuTabClick(index)
                }}
                      environments={this.state.environments}
                      envOptions={envOptions}
                      activeTab={this.state.activeTab}
                      environmentCreated={this.environmentCreated}
                      userId={this.props.match.params.id}/>
                <div className="environment">
                    <div className="inputs-container">
                        <form className="inputs" onSubmit={(event) => {
                            this.saveEnv(event)
                        }}>
                            {this.environmentNameWithSelect()}
                            <div className="env-credentials-text">Fill in the environment data</div>
                            <MyInput isLarge={true} required={true}
                                     value={this.getCorrectFieldValue("controlM")} name="Control-M"
                                     changeValue={(value) => this.changeEnvironmentProp(value, "controlM")}/>
                            <div className="two-inputs">
                                <MyInput isLarge={false} required={true}
                                         value={this.getCorrectFieldValue("username")} name="Username"
                                         changeValue={(value) => this.changeEnvironmentProp(value, "username")}/>
                                <MyInput isLarge={false} required={true} type={"password"}
                                         value={this.getCorrectFieldValue("password")} name="Password"
                                         changeValue={(value) => this.changeEnvironmentProp(value, "password")}/>
                            </div>
                            <MyInput isLarge={true} required={true}
                                     placeholder="https://example.com:8443/automation-api"
                                     value={this.getCorrectFieldValue("endpoint")} name="Endpoint"
                                     errorShown={this.state.endpointErrorShown} errorText="Please, provide valid endpoint"
                                     changeValue={(value) => this.changeEnvironmentProp(value, "endpoint")}/>
                            <div className="env-data">Fill in the default data</div>
                            <div className="two-inputs">
                                <MyInput isLarge={false} required={false}
                                         value={this.getCorrectFieldValue("jobName")} name="Job name"
                                         changeValue={(value) => this.changeEnvironmentProp(value, "jobName")}/>
                                <MyInput isLarge={false} required={false}
                                         value={this.getCorrectFieldValue("folderName")} name="Folder name"
                                         changeValue={(value) => this.changeEnvironmentProp(value, "folderName")}/>
                            </div>
                            {/*<div className="two-inputs">*/}
                                {/*<MyInput isLarge={false} required={false}*/}
                                         {/*value={this.getCorrectFieldValue("eventName")} name="Event name"*/}
                                         {/*changeValue={(value) => this.changeEnvironmentProp(value, "eventName")}/>*/}
                                {/*<MyInput isLarge={false} required={false}*/}
                                         {/*value={this.getCorrectFieldValue("fileName")} name="File name"*/}
                                         {/*changeValue={(value) => this.changeEnvironmentProp(value, "fileName")}/>*/}
                            {/*</div>*/}
                            <div className="two-inputs">
                                <MyInput isLarge={false} required={false}
                                         value={this.getCorrectFieldValue("resource")} name="Resource"
                                         changeValue={(value) => this.changeEnvironmentProp(value, "resource")}/>
                                <MyInput isLarge={false} required={false}
                                         value={this.getCorrectFieldValue("value")} name="Value"
                                         changeValue={(value) => this.changeEnvironmentProp(value, "value")}/>
                            </div>
                            <div className="display-flex">
                                <input type="submit" value="Save"
                                       className={"environment-save default-btn " + (this.compareActiveEnvironments() ? "inactive-btn" : "active-btn")}/>
                                <div
                                    className={"environment-save default-btn margin-left-auto " + (this.state.activeEnvironment.usersDefault ? "inactive-btn" : "active-btn")}
                                    onClick={this.setAsDefaultBtn}>Set as default
                                </div>
                            </div>
                        </form>
                    </div>
                    <div className="delete-btn-container">
                        <button className="delete-btn" onClick={this.deleteEnv}>
                            <img className="delete-img" src={this.state.deleteBtnImg}/>
                            <span>Delete</span>
                        </button>
                    </div>
                </div>
                <DeleteEnvironmentModal envName={this.findCurrentEnvironment()}
                                        showModal={this.state.showDeleteEnvModal}
                                        handleCloseModal={this.closeDeleteModal}
                                        deleteHandler={this.deleteHandler}/>
                <SwitchEnvironmentModal showModal={this.state.showSwitchEnvironmentModal}
                                        handleCloseModal={this.closeSwitchModal}
                                        switchEnvHandler={this.switchEnvHandler}/>
                <SetDefaultModal oldEnvName={"Environment " + this.findDefaultEnv()}
                                 newEnvName={"Environment " + this.findCurrentEnvironment()}
                                 showModal={this.state.showSetDefaultModal}
                                 handleCloseModal={this.closeSetDefaultModal}
                                 setDefault={this.setDefault}/>
            </div>
        </div>;

    }
}

export default Main;
