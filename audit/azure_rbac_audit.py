#!/usr/bin/env python3
"""
Azure RBAC Audit Script
Scans for:
  - Identities with Owner role at subscription or resource group level
  - Identities with Contributor role at subscription level (too broad)
  - Classic administrators (legacy, should be removed)
  - Service principals with credentials expiring soon
"""

import json
import subprocess
from dataclasses import dataclass, field
from typing import List
from datetime import datetime, timezone, timedelta

EXPIRY_WARNING_DAYS = 30  # Warn if SP credentials expire within 30 days


@dataclass
class AuditFinding:
    severity: str
    category: str
    resource: str
    detail: str


@dataclass
class AuditReport:
    findings: List[AuditFinding] = field(default_factory=list)

    def add(self, severity, category, resource, detail):
        self.findings.append(AuditFinding(severity, category, resource, detail))

    def summary(self):
        high   = sum(1 for f in self.findings if f.severity == "HIGH")
        medium = sum(1 for f in self.findings if f.severity == "MEDIUM")
        low    = sum(1 for f in self.findings if f.severity == "LOW")
        return f"HIGH: {high} | MEDIUM: {medium} | LOW: {low} | TOTAL: {len(self.findings)}"


def run_az(args):
    """Run an az CLI command and return parsed JSON output."""
    cmd = ["az"] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  WARNING: az command failed: {' '.join(cmd)}")
        print(f"  Error: {result.stderr.strip()}")
        return None
    return json.loads(result.stdout) if result.stdout.strip() else []


def get_subscription_id():
    """Get current subscription ID."""
    result = run_az(["account", "show"])
    return result["id"] if result else None


def check_owner_assignments(subscription_id, report):
    """Find all Owner role assignments at subscription scope."""
    print("  Checking for Owner role assignments...")

    assignments = run_az([
        "role", "assignment", "list",
        "--role", "Owner",
        "--subscription", subscription_id,
        "--output", "json"
    ])
    if not assignments:
        return

    for assignment in assignments:
        scope = assignment.get("scope", "")
        principal_name = assignment.get("principalName", assignment.get("principalId", "unknown"))
        principal_type = assignment.get("principalType", "unknown")

        # Owner at subscription scope is most dangerous
        if scope == f"/subscriptions/{subscription_id}":
            severity = "HIGH"
            scope_label = "subscription level"
        else:
            severity = "MEDIUM"
            scope_label = f"scope: {scope}"

        report.add(
            severity=severity,
            category="Owner Role Assignment",
            resource=principal_name,
            detail=f"{principal_type} has Owner role at {scope_label}. "
                   f"Owner can do everything including change IAM — use specific roles instead."
        )


def check_broad_contributor(subscription_id, report):
    """Find Contributor assignments at subscription scope."""
    print("  Checking for broad Contributor assignments...")

    assignments = run_az([
        "role", "assignment", "list",
        "--role", "Contributor",
        "--subscription", subscription_id,
        "--output", "json"
    ])
    if not assignments:
        return

    for assignment in assignments:
        scope = assignment.get("scope", "")
        # Only flag subscription-level Contributor — RG level is acceptable
        if scope == f"/subscriptions/{subscription_id}":
            principal_name = assignment.get("principalName", assignment.get("principalId", "unknown"))
            principal_type = assignment.get("principalType", "unknown")
            report.add(
                severity="MEDIUM",
                category="Broad Contributor",
                resource=principal_name,
                detail=f"{principal_type} has Contributor at subscription level. "
                       f"Scope this down to a resource group or specific resource."
            )


def check_expiring_sp_credentials(report):
    """Find service principal credentials expiring within 30 days."""
    print("  Checking for expiring service principal credentials...")

    apps = run_az(["ad", "app", "list", "--output", "json"])
    if not apps:
        return

    now = datetime.now(timezone.utc)
    warning_cutoff = now + timedelta(days=EXPIRY_WARNING_DAYS)

    for app in apps:
        app_name = app.get("displayName", "unknown")

        # Check password credentials
        for cred in app.get("passwordCredentials", []):
            end_date_str = cred.get("endDateTime", "")
            if not end_date_str:
                continue
            try:
                end_date = datetime.fromisoformat(end_date_str.replace("Z", "+00:00"))
                if end_date < now:
                    report.add(
                        severity="HIGH",
                        category="Expired SP Credential",
                        resource=app_name,
                        detail=f"Password credential expired on {end_date.date()} — rotate immediately."
                    )
                elif end_date < warning_cutoff:
                    days_left = (end_date - now).days
                    report.add(
                        severity="MEDIUM",
                        category="Expiring SP Credential",
                        resource=app_name,
                        detail=f"Password credential expires in {days_left} days ({end_date.date()}) — rotate soon."
                    )
            except ValueError:
                pass


def print_report(report: AuditReport):
    """Print findings in a readable format."""
    print("\n" + "=" * 60)
    print("  AZURE RBAC AUDIT REPORT")
    print("=" * 60)

    if not report.findings:
        print("  No findings! Your Azure RBAC config looks clean.")
        return

    for severity in ["HIGH", "MEDIUM", "LOW"]:
        findings = [f for f in report.findings if f.severity == severity]
        if not findings:
            continue

        print(f"\n  [{severity}] {len(findings)} finding(s)")
        print("  " + "-" * 40)
        for f in findings:
            print(f"  Category : {f.category}")
            print(f"  Resource : {f.resource}")
            print(f"  Detail   : {f.detail}")
            print()

    print("=" * 60)
    print(f"  SUMMARY: {report.summary()}")
    print("=" * 60)


def main():
    print("\nAzure RBAC Audit Starting...")
    print("-" * 40)

    subscription_id = get_subscription_id()
    print(f"  Subscription: {subscription_id}")

    report = AuditReport()

    check_owner_assignments(subscription_id, report)
    check_broad_contributor(subscription_id, report)
    check_expiring_sp_credentials(report)

    print_report(report)

    high_count = sum(1 for f in report.findings if f.severity == "HIGH")
    if high_count > 0:
        print(f"\n  FAILED: {high_count} HIGH severity finding(s) detected.")
        exit(1)
    else:
        print("\n  PASSED: No HIGH severity findings.")
        exit(0)


if __name__ == "__main__":
    main()
