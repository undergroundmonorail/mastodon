import React from 'react';
import { connect } from 'react-redux';
import Warning from '../components/warning';
import PropTypes from 'prop-types';
import { FormattedMessage } from 'react-intl';
import { me, softMaxChars } from 'flavours/glitch/util/initial_state';
import { profileLink, termsLink } from 'flavours/glitch/util/backend_links';

const buildHashtagRE = () => {
  try {
    const HASHTAG_SEPARATORS = "_\\u00b7\\u200c";
    const ALPHA = '\\p{L}\\p{M}';
    const WORD = '\\p{L}\\p{M}\\p{N}\\p{Pc}';
    return new RegExp(
      '(?:^|[^\\/\\)\\w])#((' +
      '[' + WORD + '_]' +
      '[' + WORD + HASHTAG_SEPARATORS + ']*' +
      '[' + ALPHA + HASHTAG_SEPARATORS + ']' +
      '[' + WORD + HASHTAG_SEPARATORS +']*' +
      '[' + WORD + '_]' +
      ')|(' +
      '[' + WORD + '_]*' +
      '[' + ALPHA + ']' +
      '[' + WORD + '_]*' +
      '))', 'iu'
    );
  } catch {
    return /(?:^|[^\/\)\w])#(\w*[a-zA-Z·]\w*)/i;
  }
};

const APPROX_HASHTAG_RE = buildHashtagRE();

const mapStateToProps = state => ({
  needsLockWarning: state.getIn(['compose', 'privacy']) === 'private' && !state.getIn(['accounts', me, 'locked']),
  hashtagWarning: state.getIn(['compose', 'privacy']) !== 'public' && APPROX_HASHTAG_RE.test(state.getIn(['compose', 'text'])),
  directMessageWarning: state.getIn(['compose', 'privacy']) === 'direct',
  lengthWarning: state.getIn(['compose', 'text']).length > softMaxChars && state.getIn(['compose', 'spoiler_text']).length === 0,
});

const WarningWrapper = ({ needsLockWarning, hashtagWarning, directMessageWarning, lengthWarning }) => {
  var warnings = [];

  if (needsLockWarning) {
    warnings.push(<Warning message={<FormattedMessage id='compose_form.lock_disclaimer' defaultMessage='Your account is not {locked}. Anyone can follow you to view your follower-only posts.' values={{ locked: <a href='/settings/profile'><FormattedMessage id='compose_form.lock_disclaimer.lock' defaultMessage='locked' /></a> }} />} />);
  }

  if (hashtagWarning) {
    warnings.push(<Warning message={<FormattedMessage id='compose_form.hashtag_warning' defaultMessage="This toot won't be listed under any hashtag as it is unlisted. Only public toots can be searched by hashtag." />} />);
  }

  if (directMessageWarning) {
    const message = (
      <span>
        <FormattedMessage id='compose_form.direct_message_warning' defaultMessage='This toot will only be sent to all the mentioned users.' /> {!!termsLink && <a href='/terms' target='_blank'><FormattedMessage id='compose_form.direct_message_warning_learn_more' defaultMessage='Learn more' /></a>}
      </span>
    );

    warnings.push(<Warning message={message} />);
  }

  if (lengthWarning) {
    warnings.push(<Warning message={<FormattedMessage id='compose_form.length_warning' defaultMessage="This toot is getting kinda long! There's no hard character limit on this instance, but please at least consider using a content warning. Not all software handles long statuses gracefully and it doesn't hurt to be considerate!" />} />);
  }

  return warnings.length > 0 ? warnings : null;
};

WarningWrapper.propTypes = {
  needsLockWarning: PropTypes.bool,
  hashtagWarning: PropTypes.bool,
  directMessageWarning: PropTypes.bool,
  lengthWarning: PropTypes.bool,
};

export default connect(mapStateToProps)(WarningWrapper);
