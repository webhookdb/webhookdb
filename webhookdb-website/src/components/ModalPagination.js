import { Button, Modal } from "react-bootstrap";

import Documentation from "../pages/documentation";
import { FaSearch } from "react-icons/fa";
import React from "react";
import TableOfContents from "./TableOfContents";

export default function ModalPagination({ mdx }) {
  const [show, setShow] = React.useState(false);

  const handleClose = () => setShow(false);
  const handleShow = () => setShow(true);

  return (
    <div className="text-center">
      <Button
        className="rounded-pill px-5 py-3"
        size="lg"
        variant="primary"
        onClick={handleShow}
      >
        Browse Docs
        <FaSearch className="ml-2" />
      </Button>

      <Modal show={show} onHide={handleClose}>
        <Modal.Header closeButton>
          <Modal.Title className="px-2">Table of Contents</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="w-100">
            <Documentation />
          </div>
          <hr />
          {mdx.tableOfContents.items && (
            <div className="w-100 px-3">
              <TableOfContents post={mdx.tableOfContents} closeModal={handleClose} />
            </div>
          )}
        </Modal.Body>
      </Modal>
    </div>
  );
}
