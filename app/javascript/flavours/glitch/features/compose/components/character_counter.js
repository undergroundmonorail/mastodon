import React from 'react';
import PropTypes from 'prop-types';
import { length } from 'stringz';

export default class CharacterCounter extends React.PureComponent {

  static propTypes = {
    text: PropTypes.string.isRequired,
    softMax: PropTypes.number.isRequired,
  };

  checkRemainingText (len) {
    if (len < this.props.softMax) {
      return <span className='character-counter character-counter--over'>{len}</span>;
    }

    return <span className='character-counter'>{len}</span>;
  }

  render () {
    return this.checkRemainingText(length(this.props.text));
  }

}
