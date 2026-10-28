source_paid_at DATETIME DEFAULT NULL,
  source_total DECIMAL(18,4) DEFAULT NULL,
  source_currency CHAR(3) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_whmcs_invoice (whmcs_invoice_id),
  KEY idx_invoice (invoice_id),
  CONSTRAINT fk_einvoice_source_invoice FOREIGN KEY (invoice_id)
    REFERENCES mod_einvoice_invoices(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mod_einvoice_lines (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  invoice_id BIGINT UNSIGNED NOT NULL,
  line_number INT UNSIGNED NOT NULL,
  whmcs_invoice_id INT UNSIGNED DEFAULT NULL,
  whmcs_item_id INT UNSIGNED DEFAULT NULL,
  description TEXT NOT NULL,
  quantity DECIMAL(18,6) NOT NULL DEFAULT 1.000000,
  unit_code VARCHAR(12) NOT NULL DEFAULT 'C62',
  unit_net_price DECIMAL(18,6) NOT NULL DEFAULT 0.000000,
  net_amount DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  tax_category VARCHAR(12) NOT NULL,
  tax_percent DECIMAL(7,4) NOT NULL DEFAULT 0.0000,
  tax_scheme VARCHAR(12) NOT NULL DEFAULT 'VAT',
  exemption_reason TEXT DEFAULT NULL,
  service_start DATE DEFAULT NULL,
  service_end DATE DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_invoice_line (invoice_id, line_number),
  KEY idx_whmcs_item (whmcs_item_id),
  CONSTRAINT fk_einvoice_line_invoice FOREIGN KEY (invoice_id)
    REFERENCES mod_einvoice_invoices(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mod_einvoice_tax_subtotals (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  invoice_id BIGINT UNSIGNED NOT NULL,
  tax_category VARCHAR(12) NOT NULL,
  tax_percent DECIMAL(7,4) NOT NULL DEFAULT 0.0000,
  tax_scheme VARCHAR(12) NOT NULL DEFAULT 'VAT',
  taxable_amount DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  tax_amount DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  exemption_reason TEXT DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_invoice (invoice_id),
  CONSTRAINT fk_einvoice_tax_invoice FOREIGN KEY (invoice_id)
    REFERENCES mod_einvoice_invoices(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mod_einvoice_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  invoice_id BIGINT UNSIGNED NOT NULL,
  xml_format VARCHAR(40) NOT NULL DEFAULT 'UBL-2.1',
  xml_profile VARCHAR(160) DEFAULT NULL,
  xml_content MEDIUMBLOB DEFAULT NULL,
  xml_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  pdf_path VARCHAR(1024) DEFAULT NULL,
  pdf_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  validation_status ENUM('pending','valid','invalid') NOT NULL DEFAULT 'pending',
  validation_report MEDIUMTEXT DEFAULT NULL,
  validated_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_invoice_document (invoice_id),
  CONSTRAINT fk_einvoice_document_invoice FOREIGN KEY (invoice_id)
    REFERENCES mod_einvoice_invoices(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mod_einvoice_deliveries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  invoice_id BIGINT UNSIGNED NOT NULL,
  channel ENUM('email','peppol','other') NOT NULL DEFAULT 'email',
  recipient VARCHAR(320) DEFAULT NULL,
  status ENUM('pending','sent','failed') NOT NULL DEFAULT 'pending',
  attempt_count INT UNSIGNED NOT NULL DEFAULT 0,
  external_reference VARCHAR(255) DEFAULT NULL,
  error_message TEXT DEFAULT NULL,
  sent_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_invoice (invoice_id),
  KEY idx_delivery_queue (status, created_at),
  CONSTRAINT fk_einvoice_delivery_invoice FOREIGN KEY (invoice_id)
    REFERENCES mod_einvoice_invoices(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mod_einvoice_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  invoice_id BIGINT UNSIGNED DEFAULT NULL,
  event_type VARCHAR(80) NOT NULL,
  actor_type ENUM('admin','cron','system','client') NOT NULL DEFAULT 'system',
  actor_id VARCHAR(64) DEFAULT NULL,
  event_data LONGTEXT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_invoice_time (invoice_id, created_at),
  KEY idx_event_time (event_type, created_at),
  CONSTRAINT fk_einvoice_event_invoice FOREIGN KEY (invoice_id)
    REFERENCES mod_einvoice_invoices(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mod_einvoice_runs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  run_type ENUM('immediate','monthly','manual','retry') NOT NULL,
  period_start DATE DEFAULT NULL,
  period_end DATE DEFAULT NULL,
  status ENUM('running','completed','failed') NOT NULL DEFAULT 'running',
  invoices_created INT UNSIGNED NOT NULL DEFAULT 0,
  sources_processed INT UNSIGNED NOT NULL DEFAULT 0,
  error_message TEXT DEFAULT NULL,
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_run_status (status, started_at),
  KEY idx_run_period (run_type, period_start, period_end)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Application requirements:
-- 1. Read WHMCS custom field 'Monthly Consolidated Invoicing' (ID to be configured).
-- 2. Allocate fiscal numbers transactionally with SELECT ... FOR UPDATE on sequences.
-- 3. Enforce immutability after issuance; store exact XML bytes and SHA-256.
-- 4. Keep PDF files outside the public web root and back them up with the DB.
-- 5. Decide fiscal timing, payment/prepayment and consolidation rules with accountant.
-- 6. Credit notes are separate documents referencing the original; sources unique constraint
