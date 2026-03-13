class ValidationError(Exception):
    """Validation error in payload or schema."""


class DependencyTimeout(Exception):
    """Timeout from downstream dependency."""


class AuthError(Exception):
    """Authentication or authorization failure."""


class SchemaMismatch(Exception):
    """Schema contract and model output mismatch."""
