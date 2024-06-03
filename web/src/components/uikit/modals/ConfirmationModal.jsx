import { defaultUndefined, ifEqElse } from "../../../modules/fp.js";
import { faCheck, faXmark } from "../../icons.jsx";
import Button from "../Button.jsx";
import Modal from "./Modal.jsx";

export default function ConfirmationModal({
  isOpen,
  heading,
  children,
  confirm,
  reject,
  confirmIcon,
  rejectIcon,
  onConfirm,
  onReject,
  ...rest
}) {
  function handleOpenChange() {
    onReject();
  }
  return (
    <Modal
      heading={heading}
      isOpen={isOpen}
      onOpenChange={handleOpenChange}
      buttons={
        <>
          {reject !== false && (
            <Button
              variant="danger"
              leftArrow={defaultUndefined(rejectIcon, faXmark)}
              onClick={() => onReject()}
            >
              {ifEqElse(reject, true, "Cancel", reject || "Cancel")}
            </Button>
          )}
          {confirm !== false && (
            <Button
              variant="primary"
              rightArrow={defaultUndefined(confirmIcon, faCheck)}
              onClick={() => onConfirm()}
            >
              {ifEqElse(confirm, true, "Confirm", confirm || "Confirm")}
            </Button>
          )}
        </>
      }
      {...rest}
    >
      {children}
    </Modal>
  );
}
