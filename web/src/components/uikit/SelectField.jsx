import Dropdown from "./Dropdown.jsx";
import InputField from "./InputField.jsx";

/**
 * @param {Array<DropdownItemProps>} items
 * @param {string} value
 * @param {InputFieldProps} props
 */
export default function SelectField({ items, ...props }) {
  return (
    <InputField
      {...props}
      renderInput={({ onChange, ...rest }) => {
        return (
          <Dropdown
            items={items}
            buttonProps={{ className: "w-100" }}
            onSelectionChange={onChange}
            {...rest}
          />
        );
      }}
    />
  );
}
