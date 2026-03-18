"""Seed MongoDB with simulation data for GigCredit backend."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from app.database import get_database


async def _create_indexes() -> None:
    db = get_database()
    await db["pan_db"].create_index("pan_number", unique=True)
    await db["aadhaar_db"].create_index("aadhaar_last4")
    await db["ifsc_db"].create_index("ifsc_code", unique=True)
    await db["loan_accounts_db"].create_index("loan_id", unique=True)


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


async def main() -> None:
    await _create_indexes()
    await _seed()
    print("Seed completed")


if __name__ == "__main__":
    asyncio.run(main())

