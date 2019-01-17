import React, {Component} from 'react';
import "./Menu.css";
import MenuButton from "./MenuButton";
import "./MenuButton.css";
import AddEnvironmentModal from './AddEnvironmentModal';

class Menu extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            logo: "img/bmcLogo.png",
            activeTab: props.activeTab,
            showModal: false
        }

        this.handleOpenModal = this.handleOpenModal.bind(this);
        this.handleCloseModal = this.handleCloseModal.bind(this);
    }

    handleOpenModal() {
        let stateCopy = this.state;
        stateCopy.showModal = true;
        this.setState(stateCopy);
    }

    handleCloseModal() {
        let stateCopy = this.state;
        stateCopy.showModal = false;
        this.setState(stateCopy);
    }

    createTabs = () => {
        let res = [];
        for (let i = 0; i < this.props.environments.length; i++) {
            res.push(<MenuButton onClick={() => {
                this.props.onClick(i)
            }}
                                 name={"Environment "+this.props.environments[i].environmentName}
                                 isActive={this.props.activeTab === i}
                                 key={i}/>);
        }
        return res;
    }

    createEnvHandler = () =>{
        let stateCopy = this.state;
        stateCopy.showModal = false;
        this.setState(stateCopy);
        this.props.environmentCreated()
    }

    render() {
        return (
            <div className="menu">
                <img className="logo" src={this.state.logo}/>
                {this.createTabs()}
                <button className="menu-btn new-environment-btn" onClick={this.handleOpenModal}>+ Add new environment
                </button>
                <AddEnvironmentModal showModal={this.state.showModal} handleCloseModal={this.handleCloseModal}
                                     createHandler={this.createEnvHandler} userId={this.props.userId} envOptions={this.props.envOptions}
                />
            </div>
        );
    }
}

export default Menu;