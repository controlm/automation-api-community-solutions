import React, {Component} from 'react';
import './App.css';
import Main from './component/Main';
import {
    BrowserRouter as Router,
    Route,
    Link
} from 'react-router-dom'

class App extends Component {
    render() {
        // return(<Main/>);
        return (<Router>
            <Route path='/:id' component={Main}/>
            {/*<Route path='/:id' component={((match) => {*/}
                {/*return <Main match={match}/>*/}
            {/*})}/>*/}
        </Router>);
    }
}

export default App;
