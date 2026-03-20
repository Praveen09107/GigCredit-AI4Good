"""Seed MongoDB with simulation data for GigCredit backend."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from app.database import get_database


async def _create_indexes() -> None:
    db = get_database()
    await db["pan_records"].create_index("pan_number", unique=True)
    await db["aadhaar_records"].create_index("aadhaar_last4")
    await db["bank_records"].create_index("ifsc_code")
    await db["bank_records"].create_index("account_number_hash")
    await db["bank_records"].create_index("loan_id")
    await db["bank_records"].create_index("utility_type")
    await db["scheme_records"].create_index("eshram_number")
    await db["scheme_records"].create_index("application_id")
    await db["scheme_records"].create_index("license_number")
    await db["scheme_records"].create_index("certificate_id")
    await db["scheme_records"].create_index("pmsym_ref")
    await db["scheme_records"].create_index("pmjjby_ref")
    await db["scheme_records"].create_index("udyam_ref")
    await db["scheme_records"].create_index("ppf_account")

    await db["pan_db"].create_index("pan_number", unique=True)
    await db["aadhaar_db"].create_index("aadhaar_last4")
    await db["ifsc_db"].create_index("ifsc_code", unique=True)
    await db["bank_accounts_db"].create_index("account_number_hash", unique=True)
    await db["vehicle_rc_db"].create_index("rc_number", unique=True)
    await db["insurance_db"].create_index("policy_number", unique=True)
    await db["itr_db"].create_index("itr_ack_number", unique=True)
    await db["gst_db"].create_index("gst_identifier", unique=True)
    await db["eshram_db"].create_index("eshram_number", unique=True)
    await db["svanidhi_db"].create_index("application_id", unique=True)
    await db["fssai_db"].create_index("license_number", unique=True)
    await db["skill_cert_db"].create_index("certificate_id", unique=True)
    await db["pmsym_db"].create_index("pmsym_ref", unique=True)
    await db["pmjjby_db"].create_index("pmjjby_ref", unique=True)
    await db["udyam_db"].create_index("udyam_ref", unique=True)
    await db["ppf_db"].create_index("ppf_account", unique=True)
    await db["loan_accounts_db"].create_index("loan_id", unique=True)
    await db["utility_bills_db"].create_index("utility_type")


async def _seed() -> None:
    now = datetime.now(timezone.utc)
    db = get_database()

    await db["pan_db"].update_one(
        {"pan_number": "ABCDE1234F"},
        {
            "$set": {
                "pan_number": "ABCDE1234F",
                "full_name": "RAVI KUMAR",
                "dob": datetime(1997, 7, 14, tzinfo=timezone.utc),
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["pan_records"].update_one(
        {"pan_number": "ABCDE1234F"},
        {
            "$set": {
                "pan_number": "ABCDE1234F",
                "full_name": "RAVI KUMAR",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["aadhaar_db"].update_one(
        {"aadhaar_last4": "4123"},
        {
            "$set": {
                "aadhaar_last4": "4123",
                "full_name": "RAVI KUMAR",
                "dob": datetime(1997, 7, 14, tzinfo=timezone.utc),
                "address_state": "Karnataka",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["aadhaar_records"].update_one(
        {"aadhaar_last4": "4123"},
        {
            "$set": {
                "aadhaar_last4": "4123",
                "full_name": "RAVI KUMAR",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["ifsc_db"].update_one(
        {"ifsc_code": "HDFC0001234"},
        {
            "$set": {
                "ifsc_code": "HDFC0001234",
                "bank_name": "HDFC Bank",
                "branch": "Koramangala",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["bank_records"].update_one(
        {"ifsc_code": "HDFC0001234"},
        {
            "$set": {
                "ifsc_code": "HDFC0001234",
                "bank_name": "HDFC Bank",
                "branch": "Koramangala",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["bank_accounts_db"].update_one(
        {"account_number_hash": "ACCT_HASH_001"},
        {
            "$set": {
                "account_number_hash": "ACCT_HASH_001",
                "ifsc_code": "HDFC0001234",
                "account_holder_name": "RAVI KUMAR",
                "bank_name": "HDFC Bank",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["bank_records"].update_one(
        {"account_number_hash": "ACCT_HASH_001"},
        {
            "$set": {
                "account_number_hash": "ACCT_HASH_001",
                "ifsc_code": "HDFC0001234",
                "account_holder_name": "RAVI KUMAR",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["vehicle_rc_db"].update_one(
        {"rc_number": "KA01AB1234"},
        {
            "$set": {
                "rc_number": "KA01AB1234",
                "owner_name": "RAVI KUMAR",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["insurance_db"].update_one(
        {"policy_number": "POL12345678"},
        {
            "$set": {
                "policy_number": "POL12345678",
                "policy_type": "Vehicle",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["itr_db"].update_one(
        {"itr_ack_number": "ITR2026ABC123"},
        {
            "$set": {
                "itr_ack_number": "ITR2026ABC123",
                "assessment_year": "2025-26",
                "status": "FILED",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["gst_db"].update_one(
        {"gst_identifier": "29ABCDE1234F1Z5"},
        {
            "$set": {
                "gst_identifier": "29ABCDE1234F1Z5",
                "legal_name": "RAVI KUMAR STORES",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["eshram_db"].update_one(
        {"eshram_number": "ESHRAM001122"},
        {
            "$set": {
                "eshram_number": "ESHRAM001122",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"eshram_number": "ESHRAM001122"},
        {
            "$set": {
                "eshram_number": "ESHRAM001122",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["svanidhi_db"].update_one(
        {"application_id": "SVAN123456"},
        {
            "$set": {
                "application_id": "SVAN123456",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"application_id": "SVAN123456"},
        {
            "$set": {
                "application_id": "SVAN123456",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["fssai_db"].update_one(
        {"license_number": "12345678901234"},
        {
            "$set": {
                "license_number": "12345678901234",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"license_number": "12345678901234"},
        {
            "$set": {
                "license_number": "12345678901234",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["skill_cert_db"].update_one(
        {"certificate_id": "SKILL-998877"},
        {
            "$set": {
                "certificate_id": "SKILL-998877",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"certificate_id": "SKILL-998877"},
        {
            "$set": {
                "certificate_id": "SKILL-998877",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["pmsym_db"].update_one(
        {"pmsym_ref": "PMSYM12345"},
        {
            "$set": {
                "pmsym_ref": "PMSYM12345",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"pmsym_ref": "PMSYM12345"},
        {
            "$set": {
                "pmsym_ref": "PMSYM12345",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["pmjjby_db"].update_one(
        {"pmjjby_ref": "PMJJBY5566"},
        {
            "$set": {
                "pmjjby_ref": "PMJJBY5566",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"pmjjby_ref": "PMJJBY5566"},
        {
            "$set": {
                "pmjjby_ref": "PMJJBY5566",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["udyam_db"].update_one(
        {"udyam_ref": "UDYAM-7788"},
        {
            "$set": {
                "udyam_ref": "UDYAM-7788",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"udyam_ref": "UDYAM-7788"},
        {
            "$set": {
                "udyam_ref": "UDYAM-7788",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["ppf_db"].update_one(
        {"ppf_account": "PPF00123456"},
        {
            "$set": {
                "ppf_account": "PPF00123456",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["scheme_records"].update_one(
        {"ppf_account": "PPF00123456"},
        {
            "$set": {
                "ppf_account": "PPF00123456",
                "status": "ACTIVE",
                "created_at": now,
            }
        },
        upsert=True,
    )

    await db["loan_accounts_db"].update_one(
        {"loan_id": "LOAN-001"},
        {
            "$set": {
                "loan_id": "LOAN-001",
                "borrower_name": "RAVI KUMAR",
                "lender": "HDFC Bank",
                "loan_type": "Vehicle",
                "emi_amount": 4250,
                "loan_status": "Active",
                "created_at": now,
            }
        },
        upsert=True,
    )
    await db["bank_records"].update_one(
        {"loan_id": "LOAN-001"},
        {
            "$set": {
                "loan_id": "LOAN-001",
                "lender": "HDFC Bank",
                "loan_status": "Active",
                "emi_amount": 4250,
                "created_at": now,
            }
        },
        upsert=True,
    )

    for utility_type, validation_mode in [
        ("ELECTRICITY", "OCR_AND_CONSISTENCY"),
        ("LPG", "OCR_CASH_TOLERANT"),
        ("MOBILE", "OCR_AND_CONSISTENCY"),
        ("RENT", "OPTIONAL_DOC"),
        ("WIFI", "OPTIONAL_DOC"),
        ("OTT", "OPTIONAL_DOC"),
    ]:
        await db["utility_bills_db"].update_one(
            {"utility_type": utility_type},
            {
                "$set": {
                    "utility_type": utility_type,
                    "validation_mode": validation_mode,
                    "status": "ACTIVE",
                    "created_at": now,
                }
            },
            upsert=True,
        )
        await db["bank_records"].update_one(
            {"utility_type": utility_type},
            {
                "$set": {
                    "utility_type": utility_type,
                    "validation_mode": validation_mode,
                    "status": "ACTIVE",
                    "created_at": now,
                }
            },
            upsert=True,
        )


async def main() -> None:
    await _create_indexes()
    await _seed()
    print("Seed completed")


if __name__ == "__main__":
    asyncio.run(main())

