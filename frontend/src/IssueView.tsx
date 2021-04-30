import React from 'react';
import styled from 'styled-components';
import { IssueViewActions, IssueViewActionsProps } from './IssueViewActions';
import { ReminderView } from './Data';
import { Reminder } from './Reminder';
import EmptyState from '@atlaskit/empty-state';
import Spinner from '@atlaskit/spinner';
import WarningIcon from '@atlaskit/icon/glyph/warning';
import Banner from '@atlaskit/banner';

const Icon = <WarningIcon label="Warning icon" secondaryColor="inherit" />;

const WarningMessage = styled.p`
    margin-left: 10px;
    margin-right: 10px;
`;

const UpgradeWarningBanner: React.SFC<{ isOpen: boolean }> = props => (
    <>
        <Banner icon={Icon} isOpen={props.isOpen} appearance="error">
            Upgrade My Reminders.
        </Banner>
        {props.isOpen && (
            <>
                <WarningMessage>
                    Reminders will not be sent until your administrator upgrades My Reminders.
                </WarningMessage>
                <br />
            </>
        )}
    </>
);

export type IssueViewProps = {
    showUpgradeWarning: boolean;
    reminders: ReminderView[] | undefined;
    timezone: string;
    onReminderDeleted(id: number): void;
};

export class IssueView extends React.PureComponent<IssueViewProps & IssueViewActionsProps> {
    private static ReminderContainer = styled.div`
        margin-top: 10px;
    `;

    private static SubInfo = styled.p`
        font-size: small;
        color: #C1C7D0;
        margin-top: 10px;
        margin-bottom: 10px;
    `;

    render() {
        return (
            <div>
                <UpgradeWarningBanner isOpen={this.props.showUpgradeWarning} />
                <IssueViewActions
                    statusIndicator={this.props.statusIndicator}
                    onAddReminder={this.props.onAddReminder}
                    onTomorrow={this.props.onTomorrow}
                    onInAWeek={this.props.onInAWeek}
                    onInAMonth={this.props.onInAMonth}
                />
                {this.ReminderView()}
            </div>
        );
    }

    private ReminderView(): JSX.Element {
        const { reminders, timezone } = this.props;
        if (!reminders) {
            return (
                <Spinner size="small" />
            );
        } else {
            if (reminders.length > 0) {
                const rs = reminders.sort((a, b) => a.expiresAt.isBefore(b.expiresAt) ? -1 : 1)
                .map(r => {
                    return (
                        <Reminder key={r.id} reminder={r} onDelete={() => this.props.onReminderDeleted(r.id)} />
                    );
                });
                return (
                    <>
                        <IssueView.ReminderContainer>{rs}</IssueView.ReminderContainer>
                        <IssueView.SubInfo>Your timezone: {timezone}</IssueView.SubInfo>
                    </>
                );
            } else {
                return (
                    <EmptyState
                        header="No reminders"
                        description="There are no pending reminders for this issue. Create some!"
                        size="narrow"
                    />
                );
            }
        }
    }
}