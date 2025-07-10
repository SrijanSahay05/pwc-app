from core_users.authentication_models import RegistrationSession, CustomUser
from core_users.models import UserApplication, EducationDetailsModel
from datetime import timedelta
from django.utils import timezone
import os

# Environment configuration
registration_expiry_hours = int(os.environ.get('REGISTRATION_EXPIRY_HOURS', 24))


class AuthenticationServices:
    """Services related to user registration flow"""

    @staticmethod
    def start_registration(email, phone, first_name, last_name):
        """
        Starts a new Registration Process
        
        PHASE 1: Validate user data uniqueness
        PHASE 2: Create registration session with expiry
        PHASE 3: Return session for OTP verification
        """
        # PHASE 1: Check if email or phone already exists
        if CustomUser.objects.filter(email=email).exists():
            return False, "Email already registered", None
        if CustomUser.objects.filter(phone=phone).exists():
            return False, "Phone already registered", None

        # PHASE 2: Calculate expiry time and create session
        expiry_time = timezone.now() + timedelta(hours=registration_expiry_hours)

        registration_session = RegistrationSession.objects.create(
            email=email,
            phone=phone,
            first_name=first_name,
            last_name=last_name,
            expires_at=expiry_time
        )
        registration_session.save()

        # PHASE 3: Return success with session object
        return True, "Registration Started", registration_session

    @staticmethod
    def update_verification_status(session_id, verification_type):
        """
        Update verification status for the Registration Sessions
        
        PHASE 1: Retrieve session by ID
        PHASE 2: Update verification status based on type
        PHASE 3: Save and return result
        """
        try:
            # PHASE 1: Get registration session
            session = RegistrationSession.objects.get(id=session_id)

            # PHASE 2: Update verification status
            if verification_type == 'email':
                session.is_email_verified = True
            else:
                session.is_phone_verified = True

            # PHASE 3: Save changes
            session.save()
            return True, "Verification Status Updated"

        except Exception as e:
            return False, f"Error encountered: {str(e)}"

    @staticmethod
    def complete_registration(session_id, password):
        """
        Create the CustomUser object and complete registration
        
        PHASE 1: Validate session and verification status
        PHASE 2: Create CustomUser with session data
        PHASE 3: Create associated models (UserApplication, EducationDetails)
        PHASE 4: Clean up session and return user
        """
        try:
            # PHASE 1: Retrieve and validate session
            session = RegistrationSession.objects.get(id=session_id)

            if session.is_expired():
                return False, "Registration Session has Expired", None

            if not (session.is_email_verified and session.is_phone_verified):
                return False, "Email or Phone verification still pending", None

            # PHASE 2: Create CustomUser with session data
            user = CustomUser.objects.create(
                email=session.email,
                phone=session.phone,
                first_name=session.first_name,
                last_name=session.last_name
            )
            user.set_password(password)
            user.save()

            # PHASE 3: Create associated models automatically
            # TODO: may be move this to core_users.signals
            application = UserApplication.objects.create(user=user)
            application.save()

            education_details = EducationDetailsModel.objects.create(
                user=user, 
                user_application=application
            )
            education_details.save()

            # PHASE 4: Clean up session and return user
            session.delete()
            return True, "User has been registered successfully", user

        except RegistrationSession.DoesNotExist:
            return False, "No active Registration Session found", None

        except Exception as e:
            return False, f"Error encountered: {str(e)}", None

    @staticmethod
    def reset_password(user, new_password):
        """
        Reset user password
        
        PHASE 1: Retrieve user by identifier
        PHASE 2: Update password
        PHASE 3: Save changes
        """
        try:
            # PHASE 1: Get user object
            reset_user = CustomUser.objects.get(user=user)
            
            # PHASE 2: Set new password
            reset_user.set_password(new_password)
            
            # PHASE 3: Save changes
            reset_user.save()

        except Exception as e:
            return False, f"Error encountered: {str(e)}"

# class UserApplicationServices:
#     """User Application Related Services goes here"""
#
#     @staticmethod
#     def generate_user_application_id():
#         current_year = timezone.now().year
#         last_app = UserApplication.objects.filter(
#             application_id__startswith=f'PWC{current_year}'
#         ).order_by('-application_id').first()
#
#         if last_app:
#             try:
#                 last_seq = int(last_app.application_id[5:])
#                 next_seq = last_seq + 1
#             except ValueError:
#                 next_seq = 1
#         else:
#             next_seq = 1
#
#         return f'PWC{current_year}{next_seq:05d}'
#





