import clsx from "clsx";

import Alert from "./Alert.jsx";
import Button from "./Button.jsx";

export default function FormButtons({
  submit,
  infoMessage,
  successMessage,
  errorMessage,
  disabled,
  submitProps,
  wide,
  left,
  noMargin,
  onSubmit,
}) {
  return (
    <div className={clsx("flex column w-100", !noMargin && "mt-4", !left && "align-end")}>
      {infoMessage && (
        <Alert className="mb-3" variant="info">
          {infoMessage}
        </Alert>
      )}
      {successMessage && (
        <Alert className="mb-3" variant="success" dismissable>
          {successMessage}
        </Alert>
      )}
      {errorMessage && (
        <Alert className="mb-3" variant="error" dismissable>
          {errorMessage}
        </Alert>
      )}
      <div className={clsx("flex row", wide && "w-100")}>
        <Button
          disabled={disabled}
          type="submit"
          onClick={onSubmit}
          {...submitProps}
          className={clsx(wide && "w-100", submitProps?.className)}
        >
          {submit || "Submit"}
        </Button>
      </div>
    </div>
  );
}
