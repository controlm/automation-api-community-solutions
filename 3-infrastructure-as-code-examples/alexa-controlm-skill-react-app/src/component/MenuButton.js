import React, {Component} from 'react';
import './MenuButton.css'

class MenuButton extends React.Component {

    constructor(props){
        super();
        this.props = props;
    }

    render() {
        return (
            <button onClick={this.props.onClick} className={"menu-btn " + (this.props.isActive ? "active-button" : "non-active-button")}>{this.props.name}</button>
        );
    }
}

export default MenuButton;