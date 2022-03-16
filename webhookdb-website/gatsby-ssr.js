const React = require("react");

const BodyComponents = [
  <form
    key="form-contact"
    className="invisible d-none"
    name="contact"
    data-netlify="true"
    netlify-honeypot="totallyreal"
  >
    <input name="name" />
    <input name="email" />
    <input name="message" />
  </form>,
];

exports.onRenderBody = ({ setPostBodyComponents }) => {
  setPostBodyComponents(BodyComponents);
};
