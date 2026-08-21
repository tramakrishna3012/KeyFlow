const crypto = require('node:crypto');
const { run } = require('./db');

async function logAudit({ organizationId = null, actorUserId = null, action, resourceType, resourceId = null, ipAddress = null, userAgent = null, metadata = {} }) {
  const id = crypto.randomUUID();
  await run(
    `INSERT INTO audit_logs (id, organization_id, actor_user_id, action, resource_type, resource_id, ip_address, user_agent, metadata, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
    [
      id,
      organizationId,
      actorUserId,
      action,
      resourceType,
      resourceId,
      ipAddress,
      userAgent,
      JSON.stringify(metadata)
    ]
  );
  return id;
}

module.exports = {
  logAudit
};
