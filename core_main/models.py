import os

from django.db import models
from django.utils import timezone

import os

# Environment configuration
max_allowed_attempts = os.environ.get('MAX_ALLOWED_ATTEMPTS', 3)


class OTPRecords(models.Model):
    """
    OTP records for email and phone verification
    
    Model Fields:
        - verification_type: Email or Phone verification
        - email/phone: Target identifier for OTP
        - otp_code: 6-digit OTP code
        - num_of_attempts: Number of verification attempts
        - created_at: OTP creation timestamp
        - expires_at: OTP expiry timestamp
        - is_verified: Verification status
    """
    
    VERIFICATION_TYPE_CHOICES = (
        ('email', 'Email'),
        ('phone', 'Phone'),
    )

    # Core fields
    verification_type = models.CharField(choices=VERIFICATION_TYPE_CHOICES, max_length=5)
    email = models.EmailField(null=True, blank=True)
    phone = models.CharField(max_length=10, null=True, blank=True)
    otp_code = models.CharField(max_length=6)

    # Tracking fields
    num_of_attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)

    def __str__(self):
        """
        Return string representation of OTP record
        
        PHASE 1: Determine identifier based on verification type
        PHASE 2: Return formatted string
        """
        # PHASE 1: Get identifier based on verification type
        if self.verification_type == 'email':
            identifier = self.email
        else:  # self.verification_type == 'phone'
            identifier = self.phone

        # PHASE 2: Return formatted string
        return f"OTP for {identifier} : {self.otp_code}"

    def is_expired(self):
        """
        Check if OTP has expired
        
        PHASE 1: Compare current time with expiry time
        PHASE 2: Return expiry status
        """
        # PHASE 1: Check if current time is past expiry
        return timezone.now() > self.expires_at

    def is_invalid(self):
        """
        Check if OTP is invalid due to too many attempts
        
        PHASE 1: Compare attempts with maximum allowed
        PHASE 2: Return validity status
        """
        # PHASE 1: Check if attempts exceed maximum
        return self.num_of_attempts > max_allowed_attempts