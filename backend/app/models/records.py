"""
Mongo-backed record models for GigCredit simulation datasets.

Concrete fields will be added based on `2_BACKEND_HARDENING_SPEC.md`.
"""

from pydantic import BaseModel


class PanRecord(BaseModel):
    pan: str


class AadhaarRecord(BaseModel):
    aadhaar_last4: str


class BankAccountRecord(BaseModel):
    ifsc: str
    account_number_masked: str


class LoanRecord(BaseModel):
    loan_id: str


class ScoreReportRecord(BaseModel):
    user_id: str
    score: float

