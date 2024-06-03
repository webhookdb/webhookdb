import clsx from "clsx";
import React from "react";
import {
  Header,
  ListBox,
  ListBoxItem,
  Popover,
  Button as RAButton,
  Section,
  Select,
  SelectValue,
} from "react-aria-components";

import dropdownSrc from "../../assets/images/dropdown.svg";
import useFlexiHref from "../../state/useFlexHref.js";
import "./Dropdown.css";

/**
 * @param {string} className
 * @param {Array<DropdownItemProps>} items
 * @param children
 * @param {object=} buttonProps Passed to the react-aria-components button select widget.
 * @param {function=} renderButton Override the default button. Called with {isOpen, setOpen}
 * @param {function=} renderSelectValue Render the button text.
 *   Called with {selectedItem, selectText, isPlaceholder},
 *   as per https://react-spectrum.adobe.com/react-aria/Select.html#selectvalue-1
 * @param {('white'|'grey')} variant
 * @param {string} value selectedKey
 * @param rest Passed to the react-aria-components Select input.
 */
export default function Dropdown({
  className,
  items,
  children,
  renderButton,
  buttonProps,
  variant,
  value,
  renderSelectValue,
  ...rest
}) {
  let [isOpen, setOpen] = React.useState(false);
  let button;
  if (renderButton) {
    button = renderButton({ isOpen, setOpen });
  } else {
    const { bgcolorVar, bgclass } = variants[variant] || variants.grey;
    button = (
      <RAButton
        {...buttonProps}
        style={{
          "--bgcolor": `var(${bgcolorVar})`,
          ...buttonProps?.style,
        }}
        className={clsx(
          "btn btn-md btn-secondary dropdown-button",
          bgclass,
          isOpen && "focused",
          buttonProps?.className,
        )}
      >
        <SelectValue className="mr-4">{renderSelectValue || null}</SelectValue>
        <div className="dropdown-arrow-scrim">&nbsp;</div>
        <span aria-hidden="true" className="dropdown-arrow">
          <img src={dropdownSrc} alt="" className="dropdown-icon" />
        </span>
        <div className="dropdown-edge-scrim">&nbsp;</div>
      </RAButton>
    );
  }
  items = items || [];
  return (
    <Select
      className={className}
      isOpen={isOpen}
      onOpenChange={setOpen}
      selectedKey={value}
      {...rest}
    >
      {button}
      <DropdownPopover>
        <DropdownListBox>
          {children}
          {items.map(({ value, ...rest }) => (
            <DropdownItem key={value} value={value} {...rest} />
          ))}
        </DropdownListBox>
      </DropdownPopover>
    </Select>
  );
}

const variants = {
  white: { bgcolorVar: "--color-background", bgclass: "bg-background" },
  grey: { bgcolorVar: "--color-light-grey", bgclass: "bg-light-grey" },
};

export function DropdownPopover({ className, ...rest }) {
  return <Popover className={clsx("dropdown-popover", className)} {...rest} />;
}

export function DropdownListBox({ className, ...rest }) {
  return <ListBox className={clsx("dropdown-listbox", className)} {...rest} />;
}

/**
 * @typedef DropdownItemProps
 * @property {string} value
 * @property {string=} label
 * @property {*=} children
 * @property {string=} className
 */

export function DropdownItem({ value, label, href, children, className, ...rest }) {
  children = children || label;
  const flexiref = useFlexiHref(href);
  const fixedHref = flexiref.isActuallyRelative ? flexiref.basenameHref : href;
  return (
    <ListBoxItem
      id={value}
      className={clsx("dropdown-item", className)}
      href={fixedHref}
      {...rest}
    >
      {children}
    </ListBoxItem>
  );
}

export function DropdownHeading({ children }) {
  return (
    <Section>
      <Header className="dropdown-header">{children}</Header>
    </Section>
  );
}

export function DropdownSeperator() {
  return (
    <Section>
      <Header>
        <hr className="dropdown-seperator" />
      </Header>
    </Section>
  );
}
