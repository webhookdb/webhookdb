import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import clsx from "clsx";
import isArray from "lodash/isArray";
import React from "react";
import { Dialog, Heading, Modal as RAModal } from "react-aria-components";

import { invokeIfFunc } from "../../../modules/fp.js";
import { faXmark } from "../../icons.jsx";
import Button from "../Button.jsx";
import Card from "../Card.jsx";
import Hr from "../Hr.jsx";
import Stack from "../Stack.jsx";
import "./Modal.css";

/**
 *
 * @param {string} heading
 * @param {boolean} isOpen
 * @param {function} onOpenChange
 * @param {JSX.Element|Array<JSX.Element>|function} buttons
 * @param {string} className
 * @param children
 * @param {import('react-aria-components').ModalOverlayProps} rest
 */
export default function Modal({
  heading,
  isOpen,
  onOpenChange,
  children,
  buttons,
  className,
  ...rest
}) {
  // NOTE: Nesting Modal in ModalOverlay does not seem to work.
  // This needed for a custom overlay class name, so we use react-aria-ModalOverlay
  // class to customize the overlay.
  // This code is here to avoid you accidentally using ModalOverlay
  // as intended and spending hours figuring out what's up.
  // Most likely this is a bug in 1.0.0rc1, so upgrade
  // and try to again later.
  const ModalOverlay = React.Fragment;
  const hasButtons = isArray(buttons) ? buttons.length > 0 : Boolean(buttons);
  return (
    <ModalOverlay>
      <RAModal
        isOpen={isOpen}
        onOpenChange={onOpenChange}
        className={clsx("modal", className)}
        {...rest}
      >
        <Dialog className="modal-dialog">
          {(dprops) => (
            <Card className="overflow-hidden outline-none">
              {heading && (
                <div className="modal-heading">
                  <Heading slot="title" className="modal-heading-text h6">
                    {heading}
                  </Heading>
                  <Button
                    className="modal-heading-dismiss"
                    variant="secondary"
                    onClick={() => onOpenChange(false)}
                  >
                    <FontAwesomeIcon icon={faXmark} />
                  </Button>
                </div>
              )}
              <div className="modal-body">
                {children}
                {children && hasButtons && <Hr className="my-4" />}
                {hasButtons && (
                  <Stack row gap={4} className="justify-end">
                    {invokeIfFunc(buttons, dprops)}
                  </Stack>
                )}
              </div>
            </Card>
          )}
        </Dialog>
      </RAModal>
    </ModalOverlay>
  );
}
