import * as React from 'react';
import { IssueViewComponent } from './IssueViewComponent';
import { AllRemindersView } from './AllRemindersView';
import { ReminderCreateDialog } from './ReminderCreateDialog';
import { BrowserRouter as Router, Route } from 'react-router-dom';
import { loadPageContext, PageContext } from './page-context';
import Spinner from '@atlaskit/spinner';

type AppState = {
  pageContext: PageContext | undefined;
  apLoaded: boolean;
};

class App extends React.Component<{}, AppState> {
  componentWillMount() {
    const pc = loadPageContext();

    this.setState({
      pageContext: pc,
      apLoaded: false
    });

    if (pc) {
      const script = document.createElement('script');
      script.src = `${pc.productBaseUrl}/atlassian-connect/all.js`;
      
      script.onload = () => {
        this.setState(s => {
          return {
            ...s,
            apLoaded: true
          };
        });
      };

      document.getElementsByTagName('head')[0].appendChild(script);
    }
  }

  componentDidUpdate() {
    if(this.state.apLoaded) {
      AP.resize();
    }
  }

  render() {
    if (!this.state.pageContext) {
      return <div>Error state: no page context!</div>;
    } else if (!this.state.apLoaded) {
      return <Spinner delay={100} size="large" />;
    }

    return (
      <Router>
        <div className="App">
          <Route exact={true} path="/panel/jira/reminder/simple" component={IssueViewComponent} />
          <Route exact={true} path="/panel/jira/reminders/view" component={AllRemindersView} /> 
          <Route exact={true} path="/panel/v2/jira/reminder/create" component={ReminderCreateDialog} />
        </div>
      </Router>
    );
  }
}

export default App;
