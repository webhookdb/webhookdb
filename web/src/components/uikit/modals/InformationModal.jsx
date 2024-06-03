import React from "react";

import Button from "../Button.jsx";
import Modal from "./Modal.jsx";

export default function InformationModal({
  isOpen,
  onOpenChange,
  heading,
  closeButton,
  children,
  ...rest
}) {
  let renderButtons;
  if (closeButton === true) {
    renderButtons = ({ close }) => <Button onClick={close}>Close</Button>;
  } else if (closeButton && onOpenChange) {
    renderButtons = React.cloneElement(closeButton, {
      onClick: () => onOpenChange(false),
    });
  } else if (closeButton) {
    renderButtons = ({ close }) => React.cloneElement(closeButton, { onClick: close });
  }
  return (
    <Modal
      heading={heading}
      isOpen={isOpen}
      onOpenChange={onOpenChange}
      isDismissable
      buttons={renderButtons}
      {...rest}
    >
      {children}
    </Modal>
  );
}
