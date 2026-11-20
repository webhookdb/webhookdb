import { NumberField } from "react-admin";

export default function MoneyField({ format, ...rest }) {
  const fmt = formats[format] || formats.whole;
  return <NumberField options={fmt} {...rest} />;
}

const formats = {
  cents: { style: "currency", currency: "USD" },
  whole: { style: "currency", currency: "USD", minimumFractionDigits: 0 },
};
