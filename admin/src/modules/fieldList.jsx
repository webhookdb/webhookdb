import isString from "lodash/isString";
import startCase from "lodash/startCase";
import React from "react";
import {
  BooleanField,
  DateField,
  EmailField,
  NumberField,
  ReferenceField,
  TextField,
} from "react-admin";

import CodeField from "../components/CodeField";
import LinkField from "../components/LinkField";
import SimpleArrayField from "../components/SimpleArrayField";

export default function fieldList(...fields) {
  return fields.map((f, i) => {
    if (React.isValidElement(f)) {
      return f;
    }
    if (isString(f)) {
      // Handle the shorthands
      if (f === "id") {
        return <TextField key={i} source={"id"} />;
      } else if (f === "opaqueId") {
        // Default sortable to true since this column will almost always have an index
        return <TextField key={i} source="opaqueId" label="Opaque ID" />;
      } else if (f.endsWith("At") || f === "at") {
        // Default sortable to false, if this timestamp is not indexed perf can be terrible.
        return <DateField key={f} showTime source={f} sortable={false} />;
      } else if (f === "createdBy") {
        return (
          <ReferenceField
            key={f}
            label="Created by"
            source="createdBy.id"
            reference="customers"
            link="show"
            sortable={false}
          />
        );
      } else {
        console.error("unhandled field list shorthand:", f);
        return null;
      }
    }
    const [type, source, props] = f;
    const p = { key: i, source, ...props };
    if (!p.label) {
      p.label = startCase(p.source);
    }
    if (typeof p.sortable === "undefined") {
      // Default sortable to false since it can have horrible perf impacts if the column is not indexed.
      p.sortable = false;
    }
    switch (type) {
      case "id":
        p.source = p.source || "id";
        return <TextField {...p} />;
      case "reference":
        if (!source.includes(".") && source !== "id") {
          p.source = source + ".id";
        }
        return <ReferenceField link="show" sortable={false} {...p} />;
      case "text":
        return <TextField {...p} />;
      case "boolean":
        return <BooleanField {...p} />;
      case "code":
        return <CodeField {...p} />;
      case "date":
        return <DateField {...p} />;
      case "datetime":
        return <DateField showTime {...p} />;
      case "email":
        return <EmailField {...p} />;
      case "json":
        return (
          <CodeField {...p} render={(o) => JSON.stringify(o[p.source], null, "  ")} />
        );
      case "number":
        return <NumberField {...p} />;
      case "url":
        delete p.sortable;
        return <LinkField {...p} />;
      case "array":
        return <SimpleArrayField {...p} />;
      default:
        console.error("unhandled field list:", f);
        return null;
    }
  });
}
