//  Package imports.
import classNames from 'classnames';
import PropTypes from 'prop-types';
import React from 'react';
import {
  defineMessages,
  FormattedMessage,
} from 'react-intl';
import { length } from 'stringz';

//  Components.
import Button from 'flavours/glitch/components/button';
import Icon from 'flavours/glitch/components/icon';

//  Utils.
import { maxChars } from 'flavours/glitch/util/initial_state';

//  Messages.
const messages = defineMessages({
  publish: {
    defaultMessage: 'Toot',
    id: 'compose_form.publish',
  },
  publishLoud: {
    defaultMessage: '{publish}!',
    id: 'compose_form.publish_loud',
  },
});

//  The component.
export default function ComposerPublisher ({
  countText,
  lengthWarning,
  disabled,
  intl,
  onSecondarySubmit,
  onSubmit,
  privacy,
  sideArm,
}) {
  const len = length(countText || '');
  const diff = maxChars - len;
  const computedClass = classNames('composer--publisher', {
    over: lengthWarning,
  });

  //  The result.
  return (
    <div className={computedClass}>
      <span className='count'>{len}</span>
      {sideArm && sideArm !== 'none' ? (
        <Button
          className='side_arm'
          disabled={disabled}
          onClick={onSecondarySubmit}
          style={{ padding: null }}
          text={
            <span>
              <Icon
                icon={{
                  public: 'globe',
                  unlisted: 'unlock',
                  private: 'lock',
                  direct: 'envelope',
                }[sideArm]}
              />
            </span>
          }
          title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${sideArm}.short` })}`}
        />
      ) : null}
      <Button
        className='primary'
        text={function () {
          switch (true) {
          case !!sideArm && sideArm !== 'none':
          case privacy === 'direct':
          case privacy === 'private':
            return (
              <span>
                <Icon
                  icon={{
                    direct: 'envelope',
                    private: 'lock',
                    public: 'globe',
                    unlisted: 'unlock',
                  }[privacy]}
                />
                {' '}
                <FormattedMessage {...messages.publish} />
              </span>
            );
          case privacy === 'public':
            return (
              <span>
                <FormattedMessage
                  {...messages.publishLoud}
                  values={{ publish: <FormattedMessage {...messages.publish} /> }}
                />
              </span>
            );
          default:
            return <span><FormattedMessage {...messages.publish} /></span>;
          }
        }()}
        title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${privacy}.short` })}`}
        onClick={onSubmit}
        disabled={disabled}
      />
    </div>
  );
}

//  Props.
ComposerPublisher.propTypes = {
  countText: PropTypes.string,
  disabled: PropTypes.bool,
  intl: PropTypes.object.isRequired,
  onSecondarySubmit: PropTypes.func,
  onSubmit: PropTypes.func,
  privacy: PropTypes.oneOf(['direct', 'private', 'unlisted', 'public']),
  sideArm: PropTypes.oneOf(['none', 'direct', 'private', 'unlisted', 'public']),
};
