#!/usr/bin/env python3
"""
AWS IAM Audit Script
Scans for:
  - IAM policies with wildcard (*) actions or resources
  - IAM users without MFA enabled
  - IAM roles not used in 90+ days
  - IAM users with active access keys older than 90 days
"""

import boto3
import json
from datetime import datetime, timezone, timedelta
from dataclasses import dataclass, field
from typing import List

DAYS_THRESHOLD = 90


@dataclass
class AuditFinding:
    severity: str      # HIGH / MEDIUM / LOW
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


def check_wildcard_policies(iam, report):
    """Scan all customer-managed policies for wildcard actions or resources."""
    print("  Checking for wildcard policies...")

    paginator = iam.get_paginator("list_policies")
    for page in paginator.paginate(Scope="Local"):  # Local = customer-managed only
        for policy in page["Policies"]:
            version = iam.get_policy_version(
                PolicyArn=policy["Arn"],
                VersionId=policy["DefaultVersionId"]
            )
            statements = version["PolicyVersion"]["Document"].get("Statement", [])
            if isinstance(statements, dict):
                statements = [statements]

            for stmt in statements:
                if stmt.get("Effect") != "Allow":
                    continue

                actions   = stmt.get("Action", [])
                resources = stmt.get("Resource", [])

                if isinstance(actions, str):
                    actions = [actions]
                if isinstance(resources, str):
                    resources = [resources]

                # Check for wildcard action
                if "*" in actions:
                    report.add(
                        severity="HIGH",
                        category="Wildcard Policy",
                        resource=policy["PolicyName"],
                        detail=f"Policy allows Action: '*' — grants ALL AWS permissions"
                    )

                # Check for wildcard resource combined with broad actions
                if "*" in resources and any("*" in a for a in actions):
                    report.add(
                        severity="HIGH",
                        category="Wildcard Policy",
                        resource=policy["PolicyName"],
                        detail=f"Policy allows Action: '*' on Resource: '*' — full admin access"
                    )


def check_users_without_mfa(iam, report):
    """Find IAM users that have a password but no MFA device."""
    print("  Checking for users without MFA...")

    paginator = iam.get_paginator("list_users")
    for page in paginator.paginate():
        for user in page["Users"]:
            # Check if user has console access (LoginProfile)
            try:
                iam.get_login_profile(UserName=user["UserName"])
                has_console_access = True
            except iam.exceptions.NoSuchEntityException:
                has_console_access = False

            if not has_console_access:
                continue  # No console access = no MFA needed

            # Check MFA devices
            mfa_devices = iam.list_mfa_devices(UserName=user["UserName"])
            if not mfa_devices["MFADevices"]:
                report.add(
                    severity="HIGH",
                    category="No MFA",
                    resource=user["UserName"],
                    detail="User has console access but NO MFA device configured"
                )


def check_unused_roles(iam, report):
    """Find IAM roles not used in the last 90 days."""
    print("  Checking for unused roles...")

    cutoff = datetime.now(timezone.utc) - timedelta(days=DAYS_THRESHOLD)
    paginator = iam.get_paginator("list_roles")

    for page in paginator.paginate():
        for role in page["Roles"]:
            # Skip AWS service-linked roles
            if role["Path"].startswith("/aws-service-role/"):
                continue

            role_detail = iam.get_role(RoleName=role["RoleName"])["Role"]
            last_used = role_detail.get("RoleLastUsed", {})
            last_used_date = last_used.get("LastUsedDate")

            if last_used_date is None:
                report.add(
                    severity="MEDIUM",
                    category="Unused Role",
                    resource=role["RoleName"],
                    detail=f"Role has NEVER been used — consider deleting it"
                )
            elif last_used_date < cutoff:
                days_ago = (datetime.now(timezone.utc) - last_used_date).days
                report.add(
                    severity="LOW",
                    category="Unused Role",
                    resource=role["RoleName"],
                    detail=f"Role last used {days_ago} days ago (threshold: {DAYS_THRESHOLD} days)"
                )


def check_old_access_keys(iam, report):
    """Find access keys older than 90 days."""
    print("  Checking for old access keys...")

    cutoff = datetime.now(timezone.utc) - timedelta(days=DAYS_THRESHOLD)
    paginator = iam.get_paginator("list_users")

    for page in paginator.paginate():
        for user in page["Users"]:
            keys = iam.list_access_keys(UserName=user["UserName"])["AccessKeyMetadata"]
            for key in keys:
                if key["Status"] == "Active" and key["CreateDate"] < cutoff:
                    days_old = (datetime.now(timezone.utc) - key["CreateDate"]).days
                    report.add(
                        severity="MEDIUM",
                        category="Old Access Key",
                        resource=user["UserName"],
                        detail=f"Active access key {key['AccessKeyId'][:8]}... is {days_old} days old — rotate it"
                    )


def print_report(report: AuditReport):
    """Print findings in a readable format."""
    print("\n" + "=" * 60)
    print("  AWS IAM AUDIT REPORT")
    print("=" * 60)

    if not report.findings:
        print("  No findings! Your IAM config looks clean.")
        return

    # Group by severity
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
    print("\nAWS IAM Audit Starting...")
    print("-" * 40)

    iam = boto3.client("iam")
    report = AuditReport()

    check_wildcard_policies(iam, report)
    check_users_without_mfa(iam, report)
    check_unused_roles(iam, report)
    check_old_access_keys(iam, report)

    print_report(report)

    # Exit with error code if HIGH findings exist (useful for CI/CD)
    high_count = sum(1 for f in report.findings if f.severity == "HIGH")
    if high_count > 0:
        print(f"\n  FAILED: {high_count} HIGH severity finding(s) detected.")
        exit(1)
    else:
        print("\n  PASSED: No HIGH severity findings.")
        exit(0)


if __name__ == "__main__":
    main()
