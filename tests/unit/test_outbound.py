import pytest

from honor_api.outbound import UnsafeOutboundTarget, validate_https_target


def test_outbound_requires_explicit_https_allowlist():
    assert validate_https_target(
        "https://api.openai.com/v1/models", allowed_hosts={"api.openai.com"}
    ).startswith("https://")
    for target in (
        "http://api.openai.com/v1/models",
        "https://127.0.0.1/admin",
        "https://169.254.169.254/latest/meta-data",
        "https://example.com/",
        "https://user:pass@api.openai.com/v1/models",
    ):
        with pytest.raises(UnsafeOutboundTarget):
            validate_https_target(target, allowed_hosts={"api.openai.com"})
