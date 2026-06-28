CREATE TABLE IF NOT EXISTS tenants (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS campaigns (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tenant_id BIGINT UNSIGNED NOT NULL,
    code VARCHAR(60) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    status ENUM('draft', 'active', 'paused', 'closed') NOT NULL DEFAULT 'draft',
    max_attempts TINYINT UNSIGNED NOT NULL DEFAULT 3,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_campaigns_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS agents (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tenant_id BIGINT UNSIGNED NOT NULL,
    extension VARCHAR(20) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_agents_tenant_extension (tenant_id, extension),
    CONSTRAINT fk_agents_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS contacts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campaign_id BIGINT UNSIGNED NOT NULL,
    external_ref VARCHAR(100) NULL,
    phone_number VARCHAR(30) NOT NULL,
    first_name VARCHAR(120) NULL,
    last_name VARCHAR(120) NULL,
    timezone VARCHAR(80) NULL,
    contact_status ENUM('pending', 'dialing', 'contacted', 'no_answer', 'busy', 'invalid', 'closed') NOT NULL DEFAULT 'pending',
    last_attempt_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_contacts_campaign_phone (campaign_id, phone_number),
    CONSTRAINT fk_contacts_campaign FOREIGN KEY (campaign_id) REFERENCES campaigns(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS call_sessions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    call_uuid VARCHAR(80) NOT NULL UNIQUE,
    campaign_id BIGINT UNSIGNED NOT NULL,
    contact_id BIGINT UNSIGNED NOT NULL,
    agent_id BIGINT UNSIGNED NULL,
    asterisk_channel_id VARCHAR(100) NULL,
    direction ENUM('outbound', 'inbound') NOT NULL DEFAULT 'outbound',
    call_status ENUM('queued', 'ringing', 'answered', 'bridged', 'ended', 'failed') NOT NULL DEFAULT 'queued',
    disposition VARCHAR(80) NULL,
    started_at DATETIME NULL,
    answered_at DATETIME NULL,
    ended_at DATETIME NULL,
    recording_url VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_call_sessions_channel (asterisk_channel_id),
    KEY idx_call_sessions_campaign_status (campaign_id, call_status),
    KEY idx_call_sessions_contact (contact_id),
    CONSTRAINT fk_call_sessions_campaign FOREIGN KEY (campaign_id) REFERENCES campaigns(id),
    CONSTRAINT fk_call_sessions_contact FOREIGN KEY (contact_id) REFERENCES contacts(id),
    CONSTRAINT fk_call_sessions_agent FOREIGN KEY (agent_id) REFERENCES agents(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS call_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    call_session_id BIGINT UNSIGNED NOT NULL,
    event_type VARCHAR(80) NOT NULL,
    payload JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_call_events_session_created (call_session_id, created_at),
    CONSTRAINT fk_call_events_session FOREIGN KEY (call_session_id) REFERENCES call_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS transcriptions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    call_session_id BIGINT UNSIGNED NOT NULL,
    speaker VARCHAR(20) NOT NULL,
    segment_index INT UNSIGNED NOT NULL DEFAULT 0,
    transcript_text TEXT NOT NULL,
    language_code VARCHAR(12) NOT NULL DEFAULT 'es',
    confidence DECIMAL(5,4) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_transcriptions_session_segment (call_session_id, segment_index),
    CONSTRAINT fk_transcriptions_session FOREIGN KEY (call_session_id) REFERENCES call_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS quality_reviews (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    call_session_id BIGINT UNSIGNED NOT NULL,
    quality_score DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    sentiment ENUM('positive', 'neutral', 'negative') NOT NULL DEFAULT 'neutral',
    opportunity_detected TINYINT(1) NOT NULL DEFAULT 0,
    notes TEXT NULL,
    reviewed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_quality_reviews_session FOREIGN KEY (call_session_id) REFERENCES call_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS opportunities (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    call_session_id BIGINT UNSIGNED NOT NULL,
    category VARCHAR(80) NOT NULL,
    priority ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'medium',
    summary VARCHAR(255) NOT NULL,
    status ENUM('open', 'assigned', 'won', 'lost') NOT NULL DEFAULT 'open',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    CONSTRAINT fk_opportunities_session FOREIGN KEY (call_session_id) REFERENCES call_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT IGNORE INTO tenants (code, name) VALUES
('default', 'Call Center Demo');

INSERT IGNORE INTO campaigns (tenant_id, code, name, status, max_attempts)
SELECT id, 'retention-q2', 'Retention Q2', 'active', 3
FROM tenants
WHERE code = 'default';

INSERT IGNORE INTO agents (tenant_id, extension, full_name, email, active)
SELECT id, '100', 'Agente Demo', 'agent@example.com', 1
FROM tenants
WHERE code = 'default';

INSERT IGNORE INTO contacts (campaign_id, external_ref, phone_number, first_name, last_name, timezone, contact_status)
SELECT c.id, 'c-0001', '+5215550100001', 'Laura', 'Pérez', 'America/Mexico_City', 'pending'
FROM campaigns c
WHERE c.code = 'retention-q2';

INSERT IGNORE INTO contacts (campaign_id, external_ref, phone_number, first_name, last_name, timezone, contact_status)
SELECT c.id, 'c-0002', '+5215550100002', 'Carlos', 'García', 'America/Mexico_City', 'pending'
FROM campaigns c
WHERE c.code = 'retention-q2';
