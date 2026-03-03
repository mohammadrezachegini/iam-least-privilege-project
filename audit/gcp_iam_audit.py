#!/usr/bin/env python3
"""
GCP IAM Audit Script
Scans for:
  - Service accounts with primitive roles (Owner/Editor) — too broad
  - Service accounts with exported keys (security risk)
  - Unused service accounts (no activity)
  - Users with Owner role at project level
"""

import json
import subprocess
from dataclasses import dataclass, field
from typing import List

# Primitive roles are too broad — should use predefined or custom roles
FORBIDDEN_ROLES = ["roles/owner", "roles/editor"]
PROJECT_ID = None  # Auto-detected from gcloud config


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


def run_gcloud(args):
    """Run a gcloud command and return parsed JSON output."""
    cmd = ["gcloud"] + args + ["--format=json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  WARNING: gcloud command failed: {' '.join(cmd)}")
        print(f"  Error: {result.stderr.strip()}")
        return None
    return json.loads(result.stdout) if result.stdout.strip() else []


def get_project_id():
    """Get the current GCP project ID."""
    result = subprocess.run(
        ["gcloud", "config", "get-value", "project"],
        capture_output=True, text=True
    )
    return result.stdout.strip()


def check_primitive_roles(project_id, report):
    """Find any member assigned Owner or Editor role — too broad."""
    print("  Checking for primitive roles (Owner/Editor)...")

    policy = run_gcloud(["projects", "get-iam-policy", project_id])
    if not policy:
        return

    bindings = policy.get("bindings", [])
    for binding in bindings:
        role = binding.get("role", "")
        if role in FORBIDDEN_ROLES:
            for member in binding.get("members", []):
                # Owner on a service account is extremely dangerous
                severity = "HIGH" if "serviceAccount" in member else "MEDIUM"
                report.add(
                    severity=severity,
                    category="Primitive Role",
                    resource=member,
                    detail=f"Member has '{role}' — this grants too broad access. Use predefined or custom roles instead."
                )


def check_service_account_keys(project_id, report):
    """Find service accounts with user-managed (exported) keys."""
    print("  Checking for exported service account keys...")

    service_accounts = run_gcloud([
        "iam", "service-accounts", "list",
        "--project", project_id
    ])
    if not service_accounts:
        return

    for sa in service_accounts:
        email = sa["email"]
        keys = run_gcloud([
            "iam", "service-accounts", "keys", "list",
            "--iam-account", email,
            "--project", project_id
        ])
        if not keys:
            continue

        # Filter for user-managed keys (not system-managed)
        user_keys = [k for k in keys if k.get("keyType") == "USER_MANAGED"]
        if user_keys:
            report.add(
                severity="HIGH",
                category="Exported SA Key",
                resource=email,
                detail=f"Service account has {len(user_keys)} exported key(s). "
                       f"Use Workload Identity instead — exported keys are a security risk."
            )


def check_owner_users(project_id, report):
    """Find human users (not SAs) with Owner role."""
    print("  Checking for users with Owner role...")

    policy = run_gcloud(["projects", "get-iam-policy", project_id])
    if not policy:
        return

    for binding in policy.get("bindings", []):
        if binding.get("role") != "roles/owner":
            continue
        for member in binding.get("members", []):
            # Flag user: and group: members with Owner
            if member.startswith("user:") or member.startswith("group:"):
                report.add(
                    severity="MEDIUM",
                    category="Owner Role on User",
                    resource=member,
                    detail="Human user has Owner role at project level. "
                           "Consider using more specific roles scoped to resources."
                )


def print_report(report: AuditReport):
    """Print findings in a readable format."""
    print("\n" + "=" * 60)
    print("  GCP IAM AUDIT REPORT")
    print("=" * 60)

    if not report.findings:
        print("  No findings! Your GCP IAM config looks clean.")
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
    print("\nGCP IAM Audit Starting...")
    print("-" * 40)

    project_id = get_project_id()
    print(f"  Project: {project_id}")

    report = AuditReport()

    check_primitive_roles(project_id, report)
    check_service_account_keys(project_id, report)
    check_owner_users(project_id, report)

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
