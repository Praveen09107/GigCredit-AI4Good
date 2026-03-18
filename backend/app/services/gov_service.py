"""
Government and bank verification simulation services.
"""

from ..models.api import ApiResponse, VerifyRequest


async def simulate_pan_lookup(payload: VerifyRequest) -> ApiResponse:
    # Placeholder; will query Mongo simulation collections.
    return ApiResponse(status="NOT_FOUND", data=None, error=None)

