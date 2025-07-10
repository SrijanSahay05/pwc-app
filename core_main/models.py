import os

from django.db import models
from django.utils import timezone

import os
# Create your models here.

max_allowed_attempts  = os.environ.get('MAX_ALLOWED_ATTEMPTS', 3)


class OTPRecords(models.Model):
    """
    OTP records, number of attempts and related information.
    Model Fields:
        -email
        -phone
        -otp_code
        -otp_type (EMAIL/PHONE)
        -num_of_attempts
        -created_at
        -expires_at
    """
    VERIFICATION_TYPE_CHOICES = (
    ('email', 'Email'),
    ('phone', 'Phone'),
    )

    verification_type = models.CharField(choices=VERIFICATION_TYPE_CHOICES, max_length=5)

    email = models.EmailField(null=True, blank=True)
    phone = models.CharField(max_length=10, null=True, blank=True)

    otp_code = models.CharField(max_length=6)

    num_of_attempts = models.PositiveSmallIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    is_verified = models.BooleanField(default=False)

    def __str__(self):
        if self.verification_type == 'email':
            identifier = self.email
        else: #self.otp_type == 'phone'
            identifier = self.phone

        return f"OTP for {identifier} : {self.otp_code}"

    def is_expired(self):
        return timezone.now()>self.expires_at

    def is_invalid(self):
        return self.num_of_attempts > max_allowed_attempts