import re

NAME_MAX = 100
EMAIL_MAX = 254  # RFC 5321 limit
MESSAGE_MAX = 2000

# Deliberately simple/conservative — real deliverability is checked by
# sending mail, not by regex. This just rejects obviously-malformed input.
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

# Reject ASCII control characters (0x00-0x1F, 0x7F) except tab/newline,
# which covers null-byte injection and other non-printable payloads.
CONTROL_CHAR_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


class ValidationError(Exception):
    def __init__(self, message: str):
        self.message = message
        super().__init__(message)


def _clean(value: str) -> str:
    return value.strip()


def validate_name(raw: str) -> str:
    value = _clean(raw)
    if not value:
        raise ValidationError("Name is required.")
    if len(value) > NAME_MAX:
        raise ValidationError(f"Name must be {NAME_MAX} characters or fewer.")
    if CONTROL_CHAR_RE.search(value):
        raise ValidationError("Name contains invalid characters.")
    return value


def validate_email(raw: str) -> str:
    value = _clean(raw)
    if not value:
        raise ValidationError("Email is required.")
    if len(value) > EMAIL_MAX:
        raise ValidationError(f"Email must be {EMAIL_MAX} characters or fewer.")
    if CONTROL_CHAR_RE.search(value):
        raise ValidationError("Email contains invalid characters.")
    if not EMAIL_RE.match(value):
        raise ValidationError("Enter a valid email address.")
    return value


def validate_message(raw: str) -> str:
    value = _clean(raw)
    if not value:
        raise ValidationError("Message is required.")
    if len(value) > MESSAGE_MAX:
        raise ValidationError(f"Message must be {MESSAGE_MAX} characters or fewer.")
    if CONTROL_CHAR_RE.search(value):
        raise ValidationError("Message contains invalid characters.")
    return value


def validate_submission(form) -> tuple[str, str, str]:
    """Validate all contact-form fields. Raises ValidationError on the
    first failure; returns the cleaned (name, email, message) tuple."""
    name = validate_name(form.get("name", ""))
    email = validate_email(form.get("email", ""))
    message = validate_message(form.get("message", ""))
    return name, email, message
