from app.api.v1.profile import _hash_password, _normalize_verification_code, _verify_password


def test_password_hash_requires_exact_password():
    encoded = _hash_password("CorrectHorseBatteryStaple")
    assert _verify_password("CorrectHorseBatteryStaple", encoded)
    assert not _verify_password("WrongPassword", encoded)


def test_verification_code_normalizes_arabic_digits_and_spaces():
    assert _normalize_verification_code(" ٠٩٦٢٥٧ ") == "096257"
    assert _normalize_verification_code("۰۹۶۲۵۷") == "096257"
