import React from 'react';
import PropTypes from 'prop-types';
import { length } from 'stringz';

export default class CharacterCounter extends React.PureComponent {

  static propTypes = {
    text: PropTypes.string.isRequired,
    spoiler: PropTypes.string.isRequired,
    max: PropTypes.number.isRequired,
  };

  checkRemainingText (len) {
    if (len > this.props.max && this.props.spoiler < 1) {
      return <span className='character-counter character-counter--over'>{len}</span>;
    }

    return <span className='character-counter'>{len}</span>;
  }

  render () {
    const len = length(this.props.text);
    return this.checkRemainingText(len);
  }

}
