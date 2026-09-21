from __future__ import annotations

import ipaddress
from urllib.parse import urlparse


class UnsafeOutboundTarget(ValueError):
    pass


def validate_https_target(url: str, *, allowed_hosts: set[str]) -> str:
    """Validate an explicitly allowlisted HTTPS provider target.

    C01 intentionally does not expose a general-purpose fetch helper. Later provider
    adapters must supply their own narrow host allowlist before performing I/O.
    """
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise UnsafeOutboundTarget("outbound target must be credential-free HTTPS")
    host = parsed.hostname.rstrip(".").lower()
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        ip = None
    if ip is not None and (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved):
        raise UnsafeOutboundTarget("private or reserved outbound address")
    normalized_allowlist = {item.rstrip(".").lower() for item in allowed_hosts}
    if host not in normalized_allowlist:
        raise UnsafeOutboundTarget("outbound host is not allowlisted")
    return url
