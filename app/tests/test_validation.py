import pytest

from validation import (
    ValidationError,
    validate_email,
    validate_message,
    validate_name,
    validate_submission,
)


class TestValidateName:
    def test_accepts_normal_name(self):
        assert validate_name("Alice") == "Alice"

    def test_strips_surrounding_whitespace(self):
        assert validate_name("  Alice  ") == "Alice"

    def test_rejects_empty(self):
        with pytest.raises(ValidationError):
            validate_name("")

    def test_rejects_whitespace_only(self):
        with pytest.raises(ValidationError):
            validate_name("   ")

    def test_rejects_over_max_length(self):
        with pytest.raises(ValidationError):
            validate_name("a" * 101)

    def test_accepts_at_max_length(self):
        assert validate_name("a" * 100) == "a" * 100

    def test_rejects_control_characters(self):
        with pytest.raises(ValidationError):
            validate_name("Bob\x07")


class TestValidateEmail:
    @pytest.mark.parametrize(
        "value",
        ["a@b.com", "first.last@example.co.uk", "user+tag@example.com"],
    )
    def test_accepts_valid_emails(self, value):
        assert validate_email(value) == value

    @pytest.mark.parametrize(
        "value",
        ["notanemail", "missing@domain", "@nouser.com", "spaces in@email.com", ""],
    )
    def test_rejects_invalid_emails(self, value):
        with pytest.raises(ValidationError):
            validate_email(value)

    def test_rejects_over_max_length(self):
        long_email = ("a" * 250) + "@b.com"
        with pytest.raises(ValidationError):
            validate_email(long_email)

    def test_rejects_control_characters(self):
        with pytest.raises(ValidationError):
            validate_email("a@b.com\x01")


class TestValidateMessage:
    def test_accepts_normal_message(self):
        assert validate_message("Hello there") == "Hello there"

    def test_rejects_empty(self):
        with pytest.raises(ValidationError):
            validate_message("   ")

    def test_rejects_over_max_length(self):
        with pytest.raises(ValidationError):
            validate_message("a" * 2001)

    def test_accepts_at_max_length(self):
        assert validate_message("a" * 2000) == "a" * 2000

    def test_rejects_null_byte(self):
        with pytest.raises(ValidationError):
            validate_message("hi\x00there")


class TestValidateSubmission:
    def test_returns_cleaned_tuple(self):
        form = {"name": " Alice ", "email": " a@b.com ", "message": " hi "}
        assert validate_submission(form) == ("Alice", "a@b.com", "hi")

    def test_raises_on_first_invalid_field(self):
        form = {"name": "", "email": "a@b.com", "message": "hi"}
        with pytest.raises(ValidationError):
            validate_submission(form)

    def test_missing_keys_treated_as_empty(self):
        with pytest.raises(ValidationError):
            validate_submission({})
