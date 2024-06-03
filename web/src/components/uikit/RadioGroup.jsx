import clsx from "clsx";
import {
  FieldError,
  Radio as RARadio,
  RadioGroup as RARadioGroup,
  Text,
} from "react-aria-components";

import InputFieldLabel from "./InputFieldLabel.jsx";
import "./RadioGroup.css";

export default function RadioGroup({
  label,
  labelHidden,
  description,
  errorMessage,
  children,
  className,
  items,
  ...props
}) {
  const groupProps = { ...props };
  if (labelHidden) {
    groupProps["aria-label"] = label;
  }
  return (
    <RARadioGroup className={clsx("radiogroup", className)} {...groupProps} {...props}>
      {label && !labelHidden && <InputFieldLabel label={label} />}
      {(items || []).map(({ label, value }) => (
        <Radio key={value} value={value}>
          {label}
        </Radio>
      ))}
      {children}
      {description && <Text slot="description">{description}</Text>}
      <FieldError>{errorMessage}</FieldError>
    </RARadioGroup>
  );
}

export function Radio({ className, ...rest }) {
  return <RARadio className={clsx("radiogroup-radio", className)} {...rest} />;
}
