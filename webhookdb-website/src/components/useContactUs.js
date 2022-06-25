import "../styles/custom.scss";

import { Button, Modal } from "react-bootstrap";

import ContactForm from "./ContactForm";
import React from "react";

const hash = "#contact-us";

export const ContactUsContext = React.createContext({
  href: "#",
  render: () => null,
  open: () => null,
  close: () => null,
});

export const useContactUs = () => React.useContext(ContactUsContext);
export default useContactUs;

export function ContactUsProvider({ children }) {
  const lastHash = React.useRef(window.location.hash);
  const [showContactUs, setShowContactUs] = React.useState(
    window.location.hash === hash
  );
  const closeContactUs = React.useCallback((e) => {
    e && e.preventDefault && e.preventDefault();
    setShowContactUs(false);
    window.location.hash = lastHash.current;
  }, []);
  const openContactUs = React.useCallback((e) => {
    e && e.preventDefault && e.preventDefault();
    setShowContactUs(true);
    lastHash.current = window.location.hash;
    window.location.hash = hash;
  }, []);
  const renderContactUs = React.useCallback(
    () => <ContactUs showContactUs={showContactUs} closeContactUs={closeContactUs} />,
    [showContactUs, closeContactUs]
  );
  return (
    <ContactUsContext.Provider
      value={{
        href: hash,
        render: renderContactUs,
        open: openContactUs,
        close: closeContactUs,
      }}
    >
      {children}
    </ContactUsContext.Provider>
  );
}

function ContactUs({ closeContactUs, showContactUs }) {
  const [state, setState] = React.useState(null);
  const [submitted, setSubmitted] = React.useState(false);

  function handleHide() {
    closeContactUs();
    window.setTimeout(() => {
      // We want to reset the form after it disappears from the DOM.
      // There are better ways to do this.
      setState(null);
      setSubmitted(false);
    }, 1000);
  }

  return (
    <Modal show={showContactUs} onHide={handleHide} animation={true} centered>
      <Modal.Header closeButton>
        <Modal.Title>Contact Us</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        {submitted ? (
          <div className="d-flex flex-column">
            <p>Thanks! We&rsquo;ll be in touch within the next business day.</p>
            <Button variant="primary" onClick={handleHide}>
              Close
            </Button>
          </div>
        ) : (
          <ContactForm
            state={state}
            setState={setState}
            onSubmitted={() => setSubmitted(true)}
          />
        )}
      </Modal.Body>
    </Modal>
  );
}
