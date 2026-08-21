const { run, get, all } = require('./db');
const { logAudit } = require('./auditService');

async function runRetentionPurgeJob() {
  const policies = await all('SELECT * FROM retention_policies WHERE auto_purge_enabled = 1');
  const results = [];

  for (const policy of policies) {
    const days = policy.retention_days || 90;
    const cutoffDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

    // Purge activity logs for users in this organization
    const deletedActivity = await run(
      `DELETE FROM activity_logs 
       WHERE started_at < ? 
       AND user_id IN (SELECT id FROM users WHERE organization_id = ?)`,
      [cutoffDate, policy.organization_id]
    );

    // Purge completed sessions older than cutoff
    const deletedSessions = await run(
      `DELETE FROM sessions 
       WHERE started_at < ? 
       AND user_id IN (SELECT id FROM users WHERE organization_id = ?)`,
      [cutoffDate, policy.organization_id]
    );

    await run('UPDATE retention_policies SET last_purged_at = datetime("now") WHERE id = ?', [policy.id]);

    await logAudit({
      organizationId: policy.organization_id,
      action: 'RETENTION_PURGE_EXECUTED',
      resourceType: 'retention_policy',
      resourceId: policy.id,
      metadata: {
        retentionDays: days,
        cutoffDate,
        deletedActivityCount: deletedActivity.changes,
        deletedSessionsCount: deletedSessions.changes
      }
    });

    results.push({
      organizationId: policy.organization_id,
      retentionDays: days,
      deletedActivityCount: deletedActivity.changes,
      deletedSessionsCount: deletedSessions.changes
    });
  }

  return results;
}

module.exports = {
  runRetentionPurgeJob
};
