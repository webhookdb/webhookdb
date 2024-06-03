import { AnimatePresence } from "framer-motion";
import React from "react";

import ShrinkingDiv from "./ShrinkingDiv.jsx";

/**
 * Visual collection of elements where items can be removed with animation.
 *
 * @param {Array<object>} items
 * @param {function} getItemKey Called for each item to get a unique key.
 * @param {function} renderItem Called with (item, {removeFromList}) for each item,
 *   and should render the inner content.
 *   Note that the content is always within an animated div.
 *   removeFromList should be called when the user starts to remove the item from the list.
 *   The value it is called with is later passed to onItemRemoved.
 * @param {string} itemClassName Class to apply to the animated div. This is usually
 *   a spacing class.
 * @param {number} exitDuration Duration of the exit animation.
 * @param {function} onItemRemoved Called after the visual item is removed from the DOM.
 *   Called with the value sent to setItemTempState.
 */
export default function AnimatedStatefulList({
  items,
  getItemKey,
  renderItem,
  itemClassName,
  exitDuration,
  onItemRemoved,
}) {
  const [hidden, setHidden] = React.useState({});
  const states = React.useRef({});
  return (
    <AnimatePresence initial={false}>
      {items.map((item) => {
        const key = getItemKey(item);
        if (hidden[key]) {
          return null;
        }
        function removeFromList(tempState) {
          setHidden({ ...hidden, [key]: true });
          states.current = { ...states, [key]: tempState };
        }
        return (
          <ShrinkingDiv
            key={key}
            itemKey={key}
            duration={exitDuration}
            className={itemClassName}
            onAnimationComplete={() => onItemRemoved(states.current[key])}
          >
            {renderItem(item, { removeFromList })}
          </ShrinkingDiv>
        );
      })}
    </AnimatePresence>
  );
}
