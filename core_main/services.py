from core_main.models import OTPRecords
from datetime import timedelta
from django.utils import timezone

import os
import random

# Environment configuration
otp_expiry_minutes = int(os.environ.get('OTP_EXPIRY_MIN', 5))


class OTPServices:
    """Services to handle OTP generation and verification"""

    @staticmethod
    def generate_code():
        """
        Generate a 6-digit OTP code
        
        PHASE 1: Generate random 6-digit number
        TODO: update the otp generation logic to a secure method before prod
        """
        return ''.join([str(random.randint(0, 9)) for _ in range(6)])

    @staticmethod
    def generate_otp_record(verification_type, identifier):
        """
        Generate OTP record for email or phone verification
        
        PHASE 1: Generate OTP code and calculate expiry
        PHASE 2: Create OTP record based on verification type
        PHASE 3: Save and return OTP record
        """
        # PHASE 1: Generate OTP code and expiry time
        otp_code = OTPServices.generate_code()
        expires_at = timezone.now() + timedelta(minutes=otp_expiry_minutes)

        # PHASE 2: Create OTP record based on verification type
        if verification_type == 'email':
            otp_record = OTPRecords.objects.create(
                verification_type=verification_type,
                email=identifier,
                otp_code=otp_code,
                expires_at=expires_at
            )
        else:  # verification_type == 'phone'
            otp_record = OTPRecords.objects.create(
                verification_type=verification_type,
                phone=identifier,
                otp_code=otp_code,
                expires_at=expires_at
            )

        # PHASE 3: Save and return OTP record
        otp_record.save()
        return otp_record

    @staticmethod
    def send_email_otp(email, otp_code):
        """
        Send OTP via email
        
        PHASE 1: Email sending logic (currently mocked)
        TODO: add actual email sending logic
        """
        # TODO: add actual email sending logic
        print(f"{otp_code} sent to {email}")

    @staticmethod
    def send_phone_otp(phone, otp_code):
        """
        Send OTP via SMS
        
        PHASE 1: SMS sending logic (currently mocked)
        TODO: add actual SMS sending logic
        """
        # TODO: add actual SMS sending logic
        print(f"{otp_code} sent to {phone}")

    @staticmethod
    def verify_otp(verification_type, identifier, otp):
        """
        Verify OTP for email or phone
        
        PHASE 1: Retrieve latest unverified OTP record
        PHASE 2: Check OTP expiry and validity
        PHASE 3: Verify OTP code and update status
        PHASE 4: Clean up and return result
        """
        try:
            # PHASE 1: Get latest unverified OTP record
            otp_record = OTPRecords.objects.filter(
                verification_type=verification_type,
                email=identifier if verification_type == 'email' else None,
                phone=identifier if verification_type == 'phone' else None,
                is_verified=False
            ).order_by('-created_at').first()

            # PHASE 2: Check OTP expiry and validity
            if otp_record.is_expired():
                return False, "OTP has expired"

            if otp_record.is_invalid():
                return False, "OTP is not valid"

            # PHASE 3: Verify OTP code
            if otp != otp_record.otp_code:
                otp_record.num_of_attempts += 1
                return False, "OTP did not match"

            # PHASE 4: Mark as verified and clean up
            otp_record.is_verified = True
            otp_record.save()
            otp_record.delete()
            return True, "OTP Verified Successfully!"

        except OTPRecords.DoesNotExist:
            return False, "No OTP Record Found"