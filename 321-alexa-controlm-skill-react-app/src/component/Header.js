import React from 'react';
import "./Header.css";

export class Header extends React.Component {

    constructor() {
        super();
        this.state = {
            logo: "img/bmcLogo.png"
        };
    }


    render() {
        return (
            <div id="toolbar">
                <img id="logo" src={this.state.logo}/>
            </div>
        );
    }
}
export default Header;