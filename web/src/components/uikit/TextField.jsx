import InputField from "./InputField.jsx";

/**
 * @param {InputFieldProps} props
 */
export default function TextField(props) {
  return (
    <InputField
      inputClassName="input-field-input"
      {...props}
      renderInput={(pr) => <input {...pr} />}
    />
  );
}
