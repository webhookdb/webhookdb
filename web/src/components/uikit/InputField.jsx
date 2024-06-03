import clsx from "clsx";
import { DialogTrigger } from "react-aria-components";

import Button from "./Button.jsx";
import "./InputField.css";
import InputFieldLabel from "./InputFieldLabel.jsx";
import InformationModal from "./modals/InformationModal.jsx";
import useUniqueId from "./useUniqueId.js";

/**
 * @typedef InputFieldProps
 * @param {string=} className
 * @param {boolean=} disabled
 * @param {string=} extra Helper text (helper, validation, or success message, usually).
 * @param {('success'|'error')=} feedback Style for extra text.
 * @param {string=} inputClassName Same as (and added to) inputProps.className.
 * @param {object=} inputProps Passed through to the inner input.
 * @param {string} label
 * @param {boolean=} marginTop If true, add a top margin. Useful when stacking inputs.
 * @param {boolean=} wide If true, add w-100 to the input.
 * @param {boolean=} readOnly
 * @param {JSX|string=} tooltip If given, show the tooltip hover with this content.
 * @param {JSX|string=} infoModal If given, add 'What is this' helper text
 *   which pops up an information modal with the given contents.
 * @param {function} renderInput Called with props to pass in the input.
 * @param {object=} rest Passed to renderInput/the input.
 */

/**
 * @param {InputFieldProps} props
 */
export default function InputField(props) {
  const {
    className,
    disabled,
    extra,
    feedback,
    inputClassName,
    inputProps,
    label,
    marginTop,
    readOnly,
    tooltip,
    infoModal,
    wide,
    renderInput,
    ...rest
  } = props;
  const feedbackCls = feedback;
  const inputCls = clsx(
    inputClassName,
    feedbackCls,
    readOnly && "readonly",
    inputProps?.className,
  );
  const uid = useUniqueId();
  return (
    <div
      className={clsx(
        "input-field",
        disabled && "disabled",
        readOnly && "readonly",
        marginTop && "mt-3",
        wide && "w-100",
        className,
      )}
    >
      <div className="flex row justify-between mb-1">
        <InputFieldLabel label={label} tooltip={tooltip} htmlFor={uid} />
        {extra && <p className={clsx("input-field-extra", feedbackCls)}>{extra}</p>}
        {infoModal && (
          <DialogTrigger>
            <Button
              variant="free"
              className={clsx(
                "input-field-extra input-field-modal-trigger text-desc",
                feedbackCls,
              )}
            >
              What is this?
            </Button>
            <InformationModal closeButton>{infoModal}</InformationModal>
          </DialogTrigger>
        )}
      </div>
      {renderInput({
        id: uid,
        disabled,
        name,
        readOnly,
        ...rest,
        ...inputProps,
        className: inputCls,
      })}
    </div>
  );
}
