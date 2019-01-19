import React from 'react';
import Motion from 'flavours/glitch/util/optional_motion';
import spring from 'react-motion/lib/spring';
import { defineMessages, FormattedMessage } from 'react-intl';

//  This is the spring used with our motion.
const motionSpring = spring(1, { damping: 35, stiffness: 400 });

//  Messages.
const messages = defineMessages({
  disclaimer: {
    defaultMessage: 'Your message is getting a little long! While there\'s no hard limit to message length here, remember that some federated software handles lengthy posts poorly. Consider throwing a CW on there.',
    id: 'compose_form.length_warning',
  },
});

//  The component.
export default function ComposerLengthWarning () {
  return (
    <Motion
      defaultStyle={{
        opacity: 0,
        scaleX: 0.85,
        scaleY: 0.75,
      }}
      style={{
        opacity: motionSpring,
        scaleX: motionSpring,
        scaleY: motionSpring,
      }}
    >
      {({ opacity, scaleX, scaleY }) => (
        <div
          className='composer--warning'
          style={{
            opacity: opacity,
            transform: `scale(${scaleX}, ${scaleY})`,
          }}
        >
          <FormattedMessage
            {...messages.disclaimer}
          />
        </div>
      )}
    </Motion>
  );
}

ComposerLengthWarning.propTypes = {};
