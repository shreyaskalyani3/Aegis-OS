# Authorized Use & Ethics

Aegis OS is a penetration-testing and security-research distribution, in the
same family as Kali Linux, BlackArch, and Parrot OS. It bundles powerful
offensive and defensive tooling. **With that capability comes responsibility.**

## The one rule

> **Only assess systems you own or have explicit, written authorization to test.**

Unauthorized access to computers and networks is a crime in most jurisdictions
(e.g. the U.S. Computer Fraud and Abuse Act, the U.K. Computer Misuse Act, and
comparable laws worldwide). Running these tools against systems, networks,
accounts, or data you do not have permission to test can expose you to criminal
prosecution and civil liability. The intent or framing of a project does not
change the law — permission does.

## Before you test

- Get authorization **in writing** (a signed scope/engagement letter, a bug
  bounty program's published policy, or ownership of the target).
- Confirm the **scope**: which hosts, IP ranges, domains, applications,
  accounts, and time windows are in bounds — and which are explicitly out.
- Agree on **rules of engagement**: allowed techniques, data-handling rules,
  points of contact, and stop conditions.
- Keep the authorization reachable during the test.

## During an engagement

- Stay **inside scope**. Don't pivot to systems that weren't authorized.
- Prefer the **least-invasive** technique that answers the question. Avoid
  denial-of-service, destructive actions, and changes you can't cleanly revert
  unless they are explicitly authorized.
- Protect the data you touch. Treat credentials, PII, and client data as
  sensitive; store findings securely and share them only with authorized parties.
- Keep accurate records so your work is reproducible and reviewable.

## AI agents and data

The bundled AI agents send the prompts and files you give them to their
providers. **Do not** paste client secrets, credentials, or out-of-scope target
data into a hosted model without authorization to do so. Review each provider's
data-handling terms, and prefer redaction when in doubt. See
[AI-AGENTS.md](AI-AGENTS.md).

## Responsible disclosure

If you discover a vulnerability, report it privately to the owner or through an
established coordinated-disclosure channel, and give them reasonable time to
remediate before any public discussion.

## Scope of this project

Aegis packages and integrates existing, publicly available security software and
AI tooling. It is provided for lawful, authorized security work, education under
proper authorization, and defensive research. The maintainers do not condone or
support unauthorized or malicious use. **You are solely responsible for how you
use it.**

Bundled third-party tools and agents are governed by their own licenses and
terms; this project's own code is under the license in [`LICENSE`](../LICENSE).
