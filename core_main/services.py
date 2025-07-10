from core_main.models import OTPRecords
from datetime import timedelta
from django.utils import timezone

import os
import random

# .env based variables
otp_expiry_minutes = int(os.environ.get('OTP_EXPIRY_MIN', 5))

class OTPServices:
    """Services to handle OTP generation and verification"""

    @staticmethod
    def generate_code():
        # TODO update the otp generation logic to a secure method before prod
        return ''.join([str(random.randint(0,9)) for _ in range(6)])

    @staticmethod
    def generate_otp_record(verification_type, identifier):
        """Generates the OTPRecord object. Service creates and returns OTPRecord object"""

        otp_code = OTPServices.generate_code()
        expires_at = timezone.now()+timedelta(minutes=otp_expiry_minutes)

        if verification_type == 'email':
            otp_record = OTPRecords.objects.create(verification_type=verification_type,
                                                   email=identifier,
                                                   otp_code=otp_code,
                                                   expires_at=expires_at)
        else: # verification_type == 'phone'
            otp_record = OTPRecords.objects.create(verification_type=verification_type,
                                                   phone=identifier,
                                                   otp_code=otp_code,
                                                   expires_at=expires_at)

        otp_record.save()
        return otp_record

    @staticmethod
    def send_email_otp(email, otp_code):
        """Emailing Logic for otp_code"""
        # TODO add actual logic
        print(f"{otp_code} sent to {email}")

    @staticmethod
    def send_phone_otp(phone, otp_code):
        """SMS sending Logic for otp_code"""
        # TODO add actual logic
        print(f"{otp_code} sent to {phone}")

    @staticmethod
    def verify_otp(verification_type, identifier, otp):
        """Verifies OTP"""

        try:
            otp_record = OTPRecords.objects.filter(verification_type=verification_type,
                                                   email=identifier if verification_type =='email' else None,
                                                   phone=identifier if verification_type =='phone' else None,
                                                   is_verified = False).order_by('-created_at').first()

            if otp_record.is_expired():
                return False, "OTP has expired"

            if otp_record.is_invalid():
                return False, "OTP is not valid"

            if otp !=otp_record.otp_code:
                otp_record.num_of_attempts += 1
                return False, "OTP did not match"

            otp_record.is_verified=True
            otp_record.save()

            otp_record.delete()
            return True, "OTP Verified Successfully!"

        except OTPRecords.DoesNotExist:
            return False, "No OTP Record Found"