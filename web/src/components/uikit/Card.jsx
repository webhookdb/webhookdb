import clsx from "clsx";

import "./Card.css";

export default function Card({ className, variant, children, ...rest }) {
  return (
    <div className={clsx("card", variant && `card-v-${variant}`, className)} {...rest}>
      {children}
    </div>
  );
}

export function CardBody({ className, children, ...rest }) {
  return (
    <div className={clsx("card-body", className)} {...rest}>
      {children}
    </div>
  );
}

export function CardTitle({ className, children, ...rest }) {
  return (
    <h6 className={clsx("mb-3", className)} {...rest}>
      {children}
    </h6>
  );
}

export function CardText({ className, children, ...rest }) {
  return (
    <p className={clsx("mb-2", className)} {...rest}>
      {children}
    </p>
  );
}
